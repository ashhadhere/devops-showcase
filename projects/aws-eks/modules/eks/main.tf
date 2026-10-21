data "aws_caller_identity" "this" {}
resource "aws_kms_key" "cluster" {
  description             = "${var.name} Kubernetes secrets envelope encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = jsonencode({ Version = "2012-10-17", Statement = [{ Sid = "DelegateToAccountIAM", Effect = "Allow", Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.this.account_id}:root" }, Action = "kms:*", Resource = "*" }] })
  tags                    = var.tags
}
module "logs" {
  source         = "../log-group"
  name           = "/aws/eks/${var.name}/cluster"
  retention_days = 30
  tags           = var.tags
}
resource "aws_iam_role" "cluster" {
  name               = "${var.name}-cluster"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "eks.amazonaws.com" }, Action = "sts:AssumeRole" }] })
  tags               = var.tags
}
resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}
resource "aws_eks_cluster" "this" {
  #checkov:skip=CKV_AWS_339:Scanner version rule is stale for EKS 1.35; verify AWS regional support before deployment. See docs/scanner-exceptions.md.
  name                      = var.name
  version                   = var.kubernetes_version
  role_arn                  = aws_iam_role.cluster.arn
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = false
  }
  upgrade_policy { support_type = "STANDARD" }
  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [aws_security_group.control_plane.id]
    endpoint_private_access = true
    endpoint_public_access  = length(var.public_access_cidrs) > 0
    public_access_cidrs     = length(var.public_access_cidrs) > 0 ? var.public_access_cidrs : null
  }
  encryption_config {
    resources = ["secrets"]
    provider { key_arn = aws_kms_key.cluster.arn }
  }
  tags       = var.tags
  depends_on = [aws_iam_role_policy_attachment.cluster, module.logs]
}
resource "aws_eks_access_entry" "admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = var.admin_role_arn
  type          = "STANDARD"
  tags          = var.tags
}
resource "aws_eks_access_policy_association" "admin" {
  cluster_name  = aws_eks_cluster.this.name
  principal_arn = aws_eks_access_entry.admin.principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  access_scope { type = "cluster" }
}
data "tls_certificate" "oidc" { url = aws_eks_cluster.this.identity[0].oidc[0].issuer }
resource "aws_iam_openid_connect_provider" "this" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]
  tags            = var.tags
}
locals { oidc_host = replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "") }
resource "aws_iam_role" "cni" {
  name               = "${var.name}-vpc-cni"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Federated = aws_iam_openid_connect_provider.this.arn }, Action = "sts:AssumeRoleWithWebIdentity", Condition = { StringEquals = { "${local.oidc_host}:aud" = "sts.amazonaws.com", "${local.oidc_host}:sub" = "system:serviceaccount:kube-system:aws-node" } } }] })
  tags               = var.tags
}
resource "aws_iam_role_policy_attachment" "cni" {
  role       = aws_iam_role.cni.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
data "aws_eks_addon_version" "this" {
  for_each           = toset(["vpc-cni", "kube-proxy", "coredns"])
  addon_name         = each.key
  kubernetes_version = var.kubernetes_version
  most_recent        = false
}
resource "aws_eks_addon" "cni" {
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = "vpc-cni"
  addon_version               = lookup(var.addon_versions, "vpc-cni", data.aws_eks_addon_version.this["vpc-cni"].version)
  service_account_role_arn    = aws_iam_role.cni.arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  depends_on                  = [aws_iam_role_policy_attachment.cni]
  tags                        = var.tags
}
resource "aws_eks_addon" "after_nodes" {
  for_each                    = toset(["kube-proxy", "coredns"])
  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = each.key
  addon_version               = lookup(var.addon_versions, each.key, data.aws_eks_addon_version.this[each.key].version)
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"
  depends_on                  = [aws_eks_node_group.this]
  tags                        = var.tags
}
