terraform {
  backend "s3" {}
}
provider "aws" {
  region              = var.region
  allowed_account_ids = [var.account_id]
  default_tags { tags = local.tags }
}
locals {
  name = "${var.project}-${var.environment}"
  tags = { Project = var.project, Environment = var.environment, ManagedBy = "Terraform", Owner = var.owner }
}
module "network" {
  source             = "../../modules/network"
  name               = local.name
  vpc_cidr           = var.vpc_cidr
  azs                = var.azs
  single_nat_gateway = var.single_nat_gateway
  tags               = local.tags
}
module "eks" {
  source               = "../../modules/eks"
  name                 = local.name
  kubernetes_version   = var.kubernetes_version
  vpc_id               = module.network.vpc_id
  private_subnet_ids   = module.network.private_subnet_ids
  admin_role_arn       = var.admin_role_arn
  public_access_cidrs  = var.public_access_cidrs
  private_access_cidrs = var.private_access_cidrs
  node_groups          = var.node_groups
  addon_versions       = var.addon_versions
  tags                 = local.tags
}
