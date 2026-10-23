mock_provider "aws" {
  mock_data "aws_caller_identity" { defaults = { account_id = "123456789012" } }
  mock_data "aws_region" { defaults = { region = "us-east-1" } }
  mock_data "aws_partition" { defaults = { partition = "aws" } }
}
variables {
  name               = "portfolio-eks-dev"
  azs                = ["us-east-1a", "us-east-1b"]
  single_nat_gateway = true
  tags               = { Project = "test" }
}
run "portfolio_network" {
  command = plan
  assert {
    condition     = length(aws_nat_gateway.this) == 1 && length(aws_subnet.private) == 2
    error_message = "Portfolio mode must keep private subnets in two AZs and one NAT."
  }
  assert {
    condition     = alltrue([for s in aws_subnet.private : !s.map_public_ip_on_launch && s.tags["kubernetes.io/role/internal-elb"] == "1"])
    error_message = "Private subnets must not assign public IPs and must support internal LB discovery."
  }
  assert {
    condition     = aws_subnet.private["us-east-1a"].cidr_block == "10.42.10.0/24" && aws_subnet.public["us-east-1b"].cidr_block == "10.42.1.0/24"
    error_message = "Public and private subnet allocations changed unexpectedly."
  }
  assert {
    condition     = aws_flow_log.this.traffic_type == "ALL" && length(aws_route_table.private) == 2
    error_message = "Flow logs and per-AZ private routing are required."
  }
}
run "resilient_network" {
  command = plan
  variables { single_nat_gateway = false }
  assert {
    condition     = length(aws_nat_gateway.this) == 2
    error_message = "Resilient mode must create a NAT per AZ."
  }
}
run "reject_single_az" {
  command = plan
  variables { azs = ["us-east-1a"] }
  expect_failures = [var.azs]
}
run "reject_duplicate_az" {
  command = plan
  variables { azs = ["us-east-1a", "us-east-1a"] }
  expect_failures = [var.azs]
}
