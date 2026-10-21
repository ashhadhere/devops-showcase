mock_provider "aws" {
  mock_data "aws_caller_identity" { defaults = { account_id = "123456789012" } }
  mock_data "aws_region" { defaults = { region = "us-east-1" } }
  mock_data "aws_partition" { defaults = { partition = "aws" } }
  mock_data "aws_eks_addon_version" { defaults = { version = "v1.0.0-eksbuild.1" } }
}
mock_provider "tls" {}
variables {
  name               = "portfolio-eks-dev"
  kubernetes_version = "1.35"
  vpc_id             = "vpc-0123456789abcdef0"
  private_subnet_ids = ["subnet-0123456789abcdef0", "subnet-1123456789abcdef0"]
  admin_role_arn     = "arn:aws:iam::123456789012:role/EKSPortfolioAdmin"
  tags               = { Project = "test" }
}
run "secure_cluster_defaults" {
  command = plan
  assert {
    condition     = aws_eks_cluster.this.vpc_config[0].endpoint_private_access && !aws_eks_cluster.this.vpc_config[0].endpoint_public_access
    error_message = "The API must be private by default."
  }
  assert {
    condition     = aws_eks_cluster.this.access_config[0].authentication_mode == "API" && !aws_eks_cluster.this.access_config[0].bootstrap_cluster_creator_admin_permissions
    error_message = "Use explicit access entries, never implicit creator admin."
  }
  assert {
    condition     = length(aws_eks_cluster.this.enabled_cluster_log_types) == 5 && aws_kms_key.cluster.enable_key_rotation
    error_message = "All five control-plane logs and rotating encryption keys are required."
  }
  assert {
    condition     = aws_launch_template.nodes["system"].metadata_options[0].http_tokens == "required" && aws_launch_template.nodes["system"].metadata_options[0].http_put_response_hop_limit == 1
    error_message = "Require IMDSv2 and prevent ordinary pods from borrowing node credentials."
  }
  assert {
    condition     = aws_launch_template.nodes["system"].block_device_mappings[0].ebs[0].encrypted && aws_eks_node_group.this["system"].scaling_config[0].desired_size == 2
    error_message = "Node disks must be encrypted and baseline desired capacity is two."
  }
}
run "restricted_public_api" {
  command = plan
  variables { public_access_cidrs = ["203.0.113.10/32"] }
  assert {
    condition     = aws_eks_cluster.this.vpc_config[0].endpoint_public_access && aws_eks_cluster.this.vpc_config[0].endpoint_private_access
    error_message = "An explicit allowlist enables public access while keeping node traffic private."
  }
}
run "reject_world_access" {
  command = plan
  variables { public_access_cidrs = ["0.0.0.0/0"] }
  expect_failures = [var.public_access_cidrs]
}
run "reject_bad_scaling" {
  command = plan
  variables { node_groups = { system = { min = 2, desired = 1, max = 3, instance_types = ["t3.medium"] } } }
  expect_failures = [var.node_groups]
}
run "reject_root_admin" {
  command = plan
  variables { admin_role_arn = "arn:aws:iam::123456789012:root" }
  expect_failures = [var.admin_role_arn]
}
run "reject_obsolete_kubernetes" {
  command = plan
  variables { kubernetes_version = "1.25" }
  expect_failures = [var.kubernetes_version]
}
