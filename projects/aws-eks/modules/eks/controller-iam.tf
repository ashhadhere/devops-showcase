# Exact upstream release policy is vendored and reviewed with the matching Helm chart.
resource "aws_iam_policy" "controller" {
  name        = "${var.name}-load-balancer-controller"
  description = "Upstream AWS LBC v3.6.0 policy; see docs/security.md for wildcard rationale"
  policy      = file("${path.module}/policies/load-balancer-controller.json")
  tags        = var.tags
}
resource "aws_iam_role" "controller" {
  name               = "${var.name}-load-balancer-controller"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Federated = aws_iam_openid_connect_provider.this.arn }, Action = "sts:AssumeRoleWithWebIdentity", Condition = { StringEquals = { "${local.oidc_host}:aud" = "sts.amazonaws.com", "${local.oidc_host}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller" } } }] })
  tags               = var.tags
}
resource "aws_iam_role_policy_attachment" "controller" {
  role       = aws_iam_role.controller.name
  policy_arn = aws_iam_policy.controller.arn
}
