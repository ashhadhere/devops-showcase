# Design tradeoffs to explain in interviews

| Decision | Why | Tradeoff / next step |
|---|---|---|
| Native local Terraform modules | Resource ownership and IAM/SG implementation are inspectable; small reusable boundaries | More maintenance than a community EKS abstraction; AWS provider changes need review |
| Separate infrastructure and Helm states | Avoid Kubernetes-provider bootstrapping cycles and allow API-independent infrastructure provisioning | Two plans and explicit outputs; destroy Helm/workloads first |
| Private API by default | Reduces external attack surface | Needs VPN or VPC runner; optional fixed-IP public API is a deliberate sandbox convenience |
| One NAT in portfolio mode | Reduces fixed monthly cost | Cross-AZ charges and AZ-A egress dependency; use one NAT per AZ for resilience |
| Two on-demand t3.medium nodes | Modest predictable starting capacity with room for system pods | Burstable and small; CPU credits/capacity limits matter; not a sizing recommendation |
| Explicit EKS access entry | Auditable identity independent of whoever ran Terraform | The initial admin remains cluster-wide privileged; create namespace-scoped team roles later |
| IRSA for CNI/controller | Exact service-account role binding, standard OIDC approach | OIDC lifecycle management; EKS Pod Identity is an alternative with its agent and trust model |
| Default compatible managed add-ons | Avoid stale hardcoded builds incompatible with a new EKS version | Initial selection requires AWS API; record reviewed exact versions before production |
| Terraform owns desired node count | Predictable configuration without an undeployed autoscaler | Bounds alone do not scale nodes; introducing Cluster Autoscaler/Karpenter requires ownership changes |
| Standard EKS support policy | Avoid surprise extended-support charges | EKS may auto-upgrade at end of standard support; schedule upgrades before that deadline |
| Official controller IAM policy | Functional reconciliation, version matched with chart | Broad discovery/create permissions remain; remove unused integrations and validate tighter scope |
| AL2023 default EKS AMI | EKS bootstraps managed nodes without custom user-data templates | New node group may select a newer release; production promotion should pin and test AMI releases |

Discuss failure cases: NAT AZ outage, nodes not spreading evenly, exhausted subnet IPs, missing access role, a private API unreachable by a hosted runner, controller webhook SG mistakes, leaked load balancers blocking VPC deletion, a KMS key disabled before log retention ends, a stale EKS minor entering auto-upgrade, and an autoscaler fighting Terraform desired capacity.

Useful demo sequence after an approved deployment: show the plan, explain subnet routes, prove nodes have no public IPs, show explicit access entries and denied unauthorized access, inspect IRSA trust claims, verify audit logs and flow logs, show a healthy controller rollout, then demonstrate ordered teardown. Do not claim these runtime checks passed until they have been executed.
