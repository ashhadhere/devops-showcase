# Portfolio assessment before adding this project

Inspected the connected `ashhadhere` repository inventory and the following existing material on 22 October 2026:

| Repository / files examined | Existing evidence | How this project complements it |
|---|---|---|
| `devops-showcase`: recursive tree, empty root README, `infrastructure/terraform-aws.tf` | Existing Jenkins, Kubernetes and Prometheus examples; Terraform file declares a single t2.medium Jenkins EC2 instance with a fixed AMI | Adds a separately rooted modular EKS project with reviewable security decisions, state handling, tests and validation CI |
| `cloudformation-vpc-multi-az`: README | Documents a two-AZ VPC with one NAT and explicitly notes absent flow logs | Demonstrates Terraform module composition, encrypted flow logs and configurable per-AZ egress |
| `cloudformation-secure-static-site-s3-cloudfront`: README | Documents S3/CloudFront origin access control | Expands the infrastructure portfolio into managed Kubernetes and workload IAM |

The CloudFormation entries above are documentation assessments, not source/runtime audits. No claim is made about their deployed resources. The broader inventory also contains WinLink-FYP, application projects, Jenkins examples and Kubernetes repositories; those were not changed or comprehensively audited in this task.

Publication is additive: `projects/aws-eks/**` plus `.github/workflows/eks-terraform.yml`. The existing root README, EC2 infrastructure example and every earlier project file are preserved. No existing Terraform state was opened, imported or migrated. No AWS API deployment was performed.
