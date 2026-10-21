terraform {
  required_version = ">= 1.13.4, < 2.0.0"
  required_providers {
    aws  = { source = "hashicorp/aws", version = "~> 6.38.0" }
    helm = { source = "hashicorp/helm", version = "~> 3.1.0" }
  }
  backend "s3" {}
}
