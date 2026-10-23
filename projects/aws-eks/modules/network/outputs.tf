output "vpc_id" { value = aws_vpc.this.id }
output "private_subnet_ids" {
  value      = [for az in var.azs : aws_subnet.private[az].id]
  depends_on = [aws_route.private, aws_route_table_association.private]
}
output "public_subnet_ids" { value = [for az in var.azs : aws_subnet.public[az].id] }
output "nat_gateway_count" { value = length(aws_nat_gateway.this) }
