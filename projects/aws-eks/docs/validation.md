# Validation evidence

Authoring checks completed on **22 October 2026** without AWS credentials or provisioning. Source and dependency validation ran on Windows; a shorter validation directory was used to avoid Windows long-path/plugin-launch limits. Public provider downloads and tool installation were allowed; no AWS deployment commands were executed.

| Check | Result |
|---|---|
| Terraform 1.13.4 `fmt -check -recursive` | Passed |
| `init -backend=false` and `validate` | Passed for bootstrap, portfolio environment, add-ons, network module and EKS module |
| Committed provider locks with readonly initialization | Passed using the locally cached, previously verified provider binaries; official archive hashes are retained in the locks |
| Network mocked plan tests | 4 passed, 0 failed |
| EKS mocked plan tests | 6 passed, 0 failed |
| TFLint 0.59.1 / AWS rules 0.45.0 | Passed with zero findings |
| Checkov 3.2.495 Terraform scan | 147 passed, 0 failed, 6 skipped instances, 0 parsing errors; 60 resources analyzed |
| Helm 3.19.0 lint of official controller 3.6.0 chart | 1 chart passed, 0 failed |
| Helm template rendering with equivalent Terraform values | Passed; inspected app image v3.6.0, two replicas and IRSA service-account annotation |
| Publication-file credential pattern check | No AWS access key IDs or private-key blocks found; examples contain deliberate dummy account IDs/configuration values |
| GitHub Action references | Each full commit SHA checked against the official release tag; workflow grants only contents-read and contains no apply job/AWS credentials |

The pinned provider selections are AWS 6.38.0, TLS 4.1.0 and Helm 3.1.2. EKS add-on builds and AMI releases cannot be locked by provider lock files. AWS's default compatible add-on lookup is mocked in tests and has not been queried against a real cluster/account.

See [raw check results](evidence/checks.json), [network test output](evidence/final-modules-network-test.txt), [EKS test output](evidence/final-modules-eks-test.txt), [scanner summary](evidence/checkov-summary.json) and [chart lint output](evidence/final-helm-lint.txt). GitHub's Linux workflow result is recorded separately in the PR checks; local Windows success alone does not claim a successful hosted workflow.

## What the tests actually establish

Tests use mocked AWS/TLS providers and `command = plan`. They check subnet allocation/tags/public-IP settings, two-AZ routing structure, NAT counts in both modes, rejected single/duplicate AZ inputs, private API defaults, explicit access mode, no creator-admin bootstrap, five control-plane log types, KMS rotation, encrypted node root disks, IMDSv2/hop limit, baseline desired capacity, optional restricted public access, rejected world-open access, rejected invalid scaling/root-admin input and rejected obsolete Kubernetes minors.

The tests establish planned Terraform properties and validation behavior. They do not prove AWS service acceptance, IAM authorization or runtime security. Checkov's six skipped instances are explicitly justified in [scanner exceptions](scanner-exceptions.md); no global skip list or soft-fail is used.

## Source review performed

Reviewed resource ownership and teardown dependencies: private routes/NAT before node provisioning; CNI IAM/add-on before managed nodes; CoreDNS/kube-proxy after nodes; separate Helm state and explicit operator session requirements; exact service-account IRSA trust claims; no automatically granted creator admin; required kubelet/admission ports; public/private subnet discovery tags; protected backend resources; and the version alignment between chart, image and vendored IAM policy. This is an authoring review, not independent reviewer approval.

## Not tested

- No credentialed Terraform plan/apply/destroy, real IAM permission evaluation, AWS quota/region/API acceptance or drift check.
- No S3 backend migration, native lock contention, state recovery, KMS recovery or cross-region disaster recovery exercise.
- No EKS node joins, pod networking/DNS, actual AMI selection, node updates, AZ failure or application availability tests.
- No verification of CloudWatch log delivery/decryption, controller IRSA credentials, webhook reachability, Helm installation or load-balancer reconciliation/cleanup in AWS.
- No live Kubernetes security assessment, penetration test, performance test, production SLO measurement or measured AWS bill.

Use the runtime acceptance checklist in [operations](operations.md) during a separately approved, budgeted sandbox deployment. This project must not be represented as production-proven until that evidence exists.
