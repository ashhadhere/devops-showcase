resource "aws_vpc_security_group_ingress_rule" "private_api" {
  for_each          = toset(var.private_access_cidrs)
  security_group_id = aws_security_group.control_plane.id
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "Routed operator VPN or runner access to private API"
}
