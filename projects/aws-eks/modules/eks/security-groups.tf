resource "aws_security_group" "control_plane" {
  name_prefix = "${var.name}-control-"
  description = "EKS API and control plane to node traffic"
  vpc_id      = var.vpc_id
  tags        = var.tags
}
resource "aws_security_group" "nodes" {
  name_prefix = "${var.name}-nodes-"
  description = "Private EKS nodes; no SSH or public ingress"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { "kubernetes.io/cluster/${var.name}" = "owned" })
}
resource "aws_vpc_security_group_ingress_rule" "node_to_api" {
  security_group_id            = aws_security_group.control_plane.id
  referenced_security_group_id = aws_security_group.nodes.id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "Nodes access private Kubernetes API"
}
resource "aws_vpc_security_group_ingress_rule" "node_internal" {
  security_group_id            = aws_security_group.nodes.id
  referenced_security_group_id = aws_security_group.nodes.id
  ip_protocol                  = "-1"
  description                  = "Node and pod communication; restrict workloads with NetworkPolicy"
}
resource "aws_vpc_security_group_ingress_rule" "control_to_nodes" {
  for_each                     = toset(["443", "10250", "9443"])
  security_group_id            = aws_security_group.nodes.id
  referenced_security_group_id = aws_security_group.control_plane.id
  ip_protocol                  = "tcp"
  from_port                    = tonumber(each.key)
  to_port                      = tonumber(each.key)
  description                  = "API to kubelet or admission webhook"
}
resource "aws_vpc_security_group_egress_rule" "control_to_nodes" {
  security_group_id            = aws_security_group.control_plane.id
  referenced_security_group_id = aws_security_group.nodes.id
  ip_protocol                  = "-1"
  description                  = "Control plane to private node group"
}
resource "aws_vpc_security_group_egress_rule" "nodes" {
  security_group_id = aws_security_group.nodes.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "NAT egress for registries and AWS APIs; deliberate portfolio tradeoff"
}
