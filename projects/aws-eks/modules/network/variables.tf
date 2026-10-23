variable "name" {
  type = string
}
variable "vpc_cidr" {
  type    = string
  default = "10.42.0.0/16"
  validation {
    condition     = can(cidrsubnet(var.vpc_cidr, 8, 255)) && endswith(var.vpc_cidr, "/16")
    error_message = "Use an IPv4 /16; subnets are deterministically allocated as /24."
  }
}
variable "azs" {
  type = list(string)
  validation {
    condition     = length(var.azs) >= 2 && length(var.azs) <= 3 && length(distinct(var.azs)) == length(var.azs)
    error_message = "Provide two or three distinct AZs in the selected region."
  }
}
variable "single_nat_gateway" {
  type = bool
}
variable "tags" {
  type = map(string)
}
