# Security decisions and residual risks

## Identity

EKS authentication uses access-entry APIs only. The Terraform creator receives no hidden admin access. One explicitly supplied existing role gets `AmazonEKSClusterAdminPolicy`; this is intentionally a privileged bootstrap/admin role, not an application identity. Restrict its trust policy with SSO/MFA and keep separate deployer/viewer roles for a real team. EKS managed node groups manage their own node access entries.

Nodes receive only `AmazonEKSWorkerNodePolicy` and `AmazonEC2ContainerRegistryPullOnly`. Those AWS-managed policies contain required discovery actions and can evolve independently of this repository. They are not `AdministratorAccess`. The VPC CNI's networking privileges are assigned to the exact `kube-system/aws-node` service account using IRSA, not attached to all nodes. The controller has its own IRSA role bound to exact `aud` and `sub` claims. Namespace/service-account control is security-sensitive.

The vendored controller policy is the official **v3.6.0** policy from [upstream](https://github.com/kubernetes-sigs/aws-load-balancer-controller/blob/v3.6.0/docs/install/iam_policy.json), SHA256 `16f232c9d9f79366fe949c4550ad517a202380058a9e48d45a4e215044a20a6a`. The Helm chart and app are both 3.6.0. AWS describe/list operations require wildcard resources; ELB resource creation and service-linked-role creation also cannot all be scoped to pre-existing ARNs. Upstream uses service/tag conditions for supported writes, but this is **not perfect per-cluster resource isolation**: some permitted operations remain broad, including optional WAF/Shield integrations. It is the functional upstream baseline, rather than an invented allow-all policy. A production security review should remove unused integration actions and add account/region/VPC/resource-tag conditions where AWS supports them, followed by reconciliation tests. Do not indiscriminately replace every `*` with a cluster ARN: that breaks APIs requiring wildcard scope.

## Network

Only public subnets route directly to the internet gateway; they do not auto-assign instance public IPs. Workers are in private subnets behind NAT and have no SSH access. Public API access is off unless explicit `/24` or narrower IPv4 CIDRs are supplied; prefer `/32`. Private API access additionally requires routed connectivity and the `private_access_cidrs` security-group allowlist. No VPN, bastion or private CI runner is provisioned.

Node ingress is limited to the node group itself, API port 443 and control-plane kubelet/webhook ports 10250/9443. Intra-node traffic and outbound NAT traffic remain broad to support pods, registries and AWS APIs. EKS also creates its own primary cluster security group, including its AWS-managed self rules; we do not claim that attaching another group removes AWS's managed rules. Custom launch templates attach only the explicit node SG, so EKS does not automatically add its primary SG to worker ENIs. The controller dynamically manages application ingress SGs after workloads request them. Audit these rules in a deployed cluster.

The VPC uses default NACLs and SGs for stateful filtering. The default VPC SG is emptied. VPC flow logs record all traffic for 30 days using a source-account constrained delivery role. An S3 gateway endpoint avoids S3 traffic through NAT; other AWS APIs and image pulls may still use NAT. Endpoint policies do not grant IAM access. Default S3 endpoint policy permits all S3 destinations subject to IAM/bucket policies; restrict destinations for regulated workloads.

## Encryption and state

EKS Kubernetes secrets use a rotating customer-managed KMS key in addition to service defaults. Node root disks use AWS-managed EBS encryption with gp3. Control-plane and VPC logs each use a dedicated rotating KMS key with CloudWatch encryption-context constraints. Account-root key-policy delegation enables account IAM administration; it is not an unconditional grant to every principal. KMS key policies use resource `*` to mean the key to which the policy is attached, not every account key.

State contains sensitive infrastructure metadata and must never enter Git. Bootstrap enables S3 versioning, block-public-access, bucket-owner-enforced ownership, KMS encryption and HTTPS-only transport. Backend config uses S3-native `.tflock` locking; no deprecated DynamoDB lock table. `prevent_destroy` is an accidental-deletion guard, not an access boundary. Administrators can change code or delete resources outside Terraform. Back up state and test restores. State access IAM is documented in operations; no long-lived keys or CI deployment role is created.

## Scope still requiring production work

This foundation does not enforce Kubernetes NetworkPolicy, Pod Security Admission, admission signatures, image vulnerability policy, app TLS/WAF, audit alerting, runtime detection, persistent-volume backup, external secret management or disaster recovery. AL2023 IMDS hop limit 1 reduces ordinary pod access to node credentials; hostNetwork/privileged workloads remain a risk. An encrypted log sink is not a monitoring/response program. No automatic AWS Budget is provisioned because budget recipients and billing access are account-specific.
