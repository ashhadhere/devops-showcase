variable "name" {
  type = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,30}$", var.name))
    error_message = "Name must be 3-31 lowercase letters, digits or hyphens, starting with a letter."
  }
}
variable "kubernetes_version" {
  type = string
  validation {
    condition     = can(regex("^1\\.[0-9]{2}$", var.kubernetes_version)) && try(tonumber(split(".", var.kubernetes_version)[1]) >= 35, false)
    error_message = "Use baseline Kubernetes 1.35 or a newer minor verified as supported in the target region; older versions are deliberately rejected."
  }
}
variable "vpc_id" {
  type = string
}
variable "private_subnet_ids" {
  type = list(string)
}
variable "admin_role_arn" {
  type = string
  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/.+$", var.admin_role_arn))
    error_message = "Supply an existing IAM role ARN, never an STS session or root ARN. Commercial AWS only."
  }
}
variable "public_access_cidrs" {
  description = "Empty means private-only. Otherwise explicitly enable public API for these IPv4 ranges."
  type        = list(string)
  default     = []
  validation {
    condition     = alltrue([for c in var.public_access_cidrs : can(cidrnetmask(c)) && try(tonumber(split("/", c)[1]) >= 24, false)])
    error_message = "API allowlists must use IPv4 CIDRs of /24 or narrower; prefer your fixed /32."
  }
}
variable "private_access_cidrs" {
  description = "Routed VPN or runner source ranges permitted to reach the private Kubernetes API."
  type        = list(string)
  default     = []
  validation {
    condition     = alltrue([for c in var.private_access_cidrs : can(cidrnetmask(c)) && try(tonumber(split("/", c)[1]) >= 16, false)])
    error_message = "Use explicit IPv4 source CIDRs of /16 or narrower for private API access."
  }
}
variable "node_groups" {
  type = map(object({
    min            = number
    desired        = number
    max            = number
    instance_types = list(string)
    capacity_type  = optional(string, "ON_DEMAND")
    disk_gb        = optional(number, 30)
  }))
  default = { system = { min = 2, desired = 2, max = 3, instance_types = ["t3.medium"] } }
  validation {
    condition     = length(var.node_groups) > 0 && alltrue([for n in var.node_groups : n.min >= 1 && n.min <= n.desired && n.desired <= n.max && n.disk_gb >= 20 && floor(n.min) == n.min && floor(n.desired) == n.desired && floor(n.max) == n.max && length(n.instance_types) > 0 && contains(["ON_DEMAND", "SPOT"], n.capacity_type)])
    error_message = "Each group requires integer 1 <= min <= desired <= max, >=20 GiB disk, instance types and ON_DEMAND or SPOT capacity."
  }
}
variable "addon_versions" {
  description = "Optional reviewed EKS add-on version overrides; absent entries resolve the AWS default compatible version at plan time."
  type        = map(string)
  default     = {}
  validation {
    condition     = alltrue([for k in keys(var.addon_versions) : contains(["vpc-cni", "kube-proxy", "coredns"], k)])
    error_message = "Only vpc-cni, kube-proxy and coredns are supported here."
  }
}
variable "tags" {
  type = map(string)
}
