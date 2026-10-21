locals {
  azs     = { for i, az in var.azs : az => i }
  nat_azs = var.single_nat_gateway ? { (var.azs[0]) = 0 } : local.azs
}
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(var.tags, { Name = var.name })
}
resource "aws_default_security_group" "this" {
  vpc_id  = aws_vpc.this.id
  ingress = []
  egress  = []
  tags    = merge(var.tags, { Name = "${var.name}-unused-default" })
}
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = var.tags
}
resource "aws_subnet" "public" {
  for_each                = local.azs
  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value)
  map_public_ip_on_launch = false
  tags                    = merge(var.tags, { Name = "${var.name}-public-${each.key}", "kubernetes.io/role/elb" = "1", "kubernetes.io/cluster/${var.name}" = "shared" })
}
resource "aws_subnet" "private" {
  for_each                = local.azs
  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value + 10)
  map_public_ip_on_launch = false
  tags                    = merge(var.tags, { Name = "${var.name}-private-${each.key}", "kubernetes.io/role/internal-elb" = "1", "kubernetes.io/cluster/${var.name}" = "shared" })
}
resource "aws_eip" "nat" {
  for_each = local.nat_azs
  domain   = "vpc"
  tags     = var.tags
}
resource "aws_nat_gateway" "this" {
  for_each      = local.nat_azs
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id
  tags          = var.tags
  depends_on    = [aws_internet_gateway.this]
}
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  tags   = var.tags
}
resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}
resource "aws_route_table_association" "public" {
  for_each       = local.azs
  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table" "private" {
  for_each = local.azs
  vpc_id   = aws_vpc.this.id
  tags     = var.tags
}
resource "aws_route" "private" {
  for_each               = local.azs
  route_table_id         = aws_route_table.private[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[var.single_nat_gateway ? var.azs[0] : each.key].id
}
resource "aws_route_table_association" "private" {
  for_each       = local.azs
  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.key].id
}
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.this.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [for table in aws_route_table.private : table.id]
  tags              = var.tags
}
data "aws_region" "this" {}
module "flow_logs" {
  source         = "../log-group"
  name           = "/vpc/${var.name}/flow"
  retention_days = 30
  tags           = var.tags
}
resource "aws_iam_role" "flow_logs" {
  name               = "${var.name}-flow-logs"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "vpc-flow-logs.amazonaws.com" }, Action = "sts:AssumeRole", Condition = { StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.this.account_id }, ArnLike = { "aws:SourceArn" = "arn:aws:ec2:${data.aws_region.this.region}:${data.aws_caller_identity.this.account_id}:vpc-flow-log/*" } } }] })
  tags               = var.tags
}
data "aws_caller_identity" "this" {}
resource "aws_iam_role_policy" "flow_logs" {
  role = aws_iam_role.flow_logs.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"], Resource = "${module.flow_logs.arn}:*" },
    { Effect = "Allow", Action = ["logs:DescribeLogGroups"], Resource = "*" }
  ] })
}
resource "aws_flow_log" "this" {
  vpc_id               = aws_vpc.this.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = module.flow_logs.arn
  iam_role_arn         = aws_iam_role.flow_logs.arn
  tags                 = var.tags
  depends_on           = [aws_iam_role_policy.flow_logs]
}
