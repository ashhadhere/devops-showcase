variable "name" {
  type = string
}
variable "retention_days" {
  type = number
}
variable "tags" {
  type = map(string)
}
data "aws_caller_identity" "this" {}
data "aws_region" "this" {}
data "aws_partition" "this" {}
locals {
  account_root = "arn:${data.aws_partition.this.partition}:iam::${data.aws_caller_identity.this.account_id}:root"
  log_arn      = "arn:${data.aws_partition.this.partition}:logs:${data.aws_region.this.region}:${data.aws_caller_identity.this.account_id}:log-group:${var.name}"
}
resource "aws_kms_key" "logs" {
  description             = "Encrypt ${var.name}"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Sid = "DelegateToAccountIAM", Effect = "Allow", Principal = { AWS = local.account_root }, Action = "kms:*", Resource = "*" },
    { Sid       = "CloudWatchEncryption", Effect = "Allow", Principal = { Service = "logs.${data.aws_region.this.region}.amazonaws.com" },
      Action    = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"], Resource = "*",
      Condition = { ArnEquals = { "kms:EncryptionContext:aws:logs:arn" = local.log_arn } }
    }
  ] })
  tags = var.tags
}
resource "aws_cloudwatch_log_group" "this" {
  #checkov:skip=CKV_AWS_338:Thirty-day retention is intentional for a disposable portfolio environment; production retention follows organizational policy.
  name              = var.name
  retention_in_days = var.retention_days
  kms_key_id        = aws_kms_key.logs.arn
  tags              = var.tags
}
output "arn" { value = aws_cloudwatch_log_group.this.arn }
output "name" { value = aws_cloudwatch_log_group.this.name }
