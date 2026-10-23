terraform {
  required_version = ">= 1.13.4, < 2.0.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.38.0" }
    tls = { source = "hashicorp/tls", version = "~> 4.1.0" }
  }
}
