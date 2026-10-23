variable "region" {
  type    = string
  default = "us-east-1"
}
variable "account_id" {
  type = string
}
variable "cluster_name" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "controller_role_arn" {
  type = string
}
provider "aws" {
  region              = var.region
  allowed_account_ids = [var.account_id]
}
data "aws_eks_cluster" "this" { name = var.cluster_name }
provider "helm" {
  kubernetes = {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.cluster_name, "--region", var.region]
    }
  }
}
resource "helm_release" "controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "3.6.0"
  namespace  = "kube-system"
  atomic     = true
  wait       = true
  timeout    = 600
  values = [yamlencode({
    clusterName                 = var.cluster_name
    region                      = var.region
    vpcId                       = var.vpc_id
    replicaCount                = 2
    serviceAccount              = { create = true, name = "aws-load-balancer-controller", annotations = { "eks.amazonaws.com/role-arn" = var.controller_role_arn } }
    enableServiceMutatorWebhook = false
  })]
}
