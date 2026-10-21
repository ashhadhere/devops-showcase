variable "region" {
  type    = string
  default = "us-east-1"
}
variable "account_id" {
  type = string
  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_id))
    error_message = "Supply the intended sandbox AWS account ID; the provider refuses other accounts."
  }
}
variable "project" {
  type    = string
  default = "portfolio-eks"
}
variable "environment" {
  type    = string
  default = "dev"
}
variable "owner" {
  type    = string
  default = "ashhadhere"
}
variable "vpc_cidr" {
  type    = string
  default = "10.42.0.0/16"
}
variable "azs" {
  type    = list(string)
  default = ["us-east-1a", "us-east-1b"]
}
variable "single_nat_gateway" {
  type    = bool
  default = true
}
variable "kubernetes_version" {
  type    = string
  default = "1.35"
}
variable "admin_role_arn" {
  type = string
}
variable "public_access_cidrs" {
  type    = list(string)
  default = []
}
variable "node_groups" {
  type    = map(object({ min = number, desired = number, max = number, instance_types = list(string), capacity_type = optional(string, "ON_DEMAND"), disk_gb = optional(number, 30) }))
  default = { system = { min = 2, desired = 2, max = 3, instance_types = ["t3.medium"] } }
}
variable "addon_versions" {
  type    = map(string)
  default = {}
}
