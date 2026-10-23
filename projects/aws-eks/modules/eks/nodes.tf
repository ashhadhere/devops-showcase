resource "aws_iam_role" "nodes" {
  name               = "${var.name}-nodes"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }] })
  tags               = var.tags
}
resource "aws_iam_role_policy_attachment" "nodes" {
  for_each   = toset(["AmazonEKSWorkerNodePolicy", "AmazonEC2ContainerRegistryPullOnly"])
  role       = aws_iam_role.nodes.name
  policy_arn = "arn:aws:iam::aws:policy/${each.key}"
}
resource "aws_launch_template" "nodes" {
  for_each               = var.node_groups
  name_prefix            = "${var.name}-${each.key}-"
  vpc_security_group_ids = [aws_security_group.nodes.id]
  update_default_version = true
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = each.value.disk_gb
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }
  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.name}-${each.key}" })
  }
  tag_specifications {
    resource_type = "volume"
    tags          = var.tags
  }
  tags = var.tags
}
resource "aws_eks_node_group" "this" {
  for_each        = var.node_groups
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.name}-${each.key}"
  node_role_arn   = aws_iam_role.nodes.arn
  subnet_ids      = var.private_subnet_ids
  version         = var.kubernetes_version
  ami_type        = "AL2023_x86_64_STANDARD"
  instance_types  = each.value.instance_types
  capacity_type   = each.value.capacity_type
  scaling_config {
    min_size     = each.value.min
    desired_size = each.value.desired
    max_size     = each.value.max
  }
  update_config { max_unavailable = 1 }
  launch_template {
    id      = aws_launch_template.nodes[each.key].id
    version = tostring(aws_launch_template.nodes[each.key].latest_version)
  }
  labels     = { pool = each.key }
  tags       = var.tags
  depends_on = [aws_iam_role_policy_attachment.nodes, aws_eks_addon.cni, aws_vpc_security_group_ingress_rule.node_to_api, aws_vpc_security_group_ingress_rule.control_to_nodes, aws_vpc_security_group_ingress_rule.node_internal, aws_vpc_security_group_egress_rule.nodes, aws_vpc_security_group_egress_rule.control_to_nodes]
}
