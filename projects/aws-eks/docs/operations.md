# State, upgrades and operational checks

## Backend bootstrap and permissions

Use a separate sandbox account and short-lived credentials. `allowed_account_ids` rejects a mismatched provider account; set it in backend config too. The bootstrap creates the backend but cannot initially depend on itself. Preserve its initial local state under your organization's encrypted backup process. For remote bootstrap state after bucket creation, add `terraform { backend "s3" {} }` to a separate `bootstrap/backend.tf`, format it as a multiline block, then run `terraform -chdir=bootstrap init -migrate-state -backend-config=backend.hcl` with a config using **`aws-eks/bootstrap/terraform.tfstate`**, not either environment key. Confirm `terraform state list` and an S3 version exist before securely retiring the local backup according to retention policy.

Grant the human/team state role only the required bucket prefix. For each state key, Terraform needs `s3:ListBucket` on the bucket with the relevant prefix, `s3:GetObject` and `s3:PutObject` on that exact state object, and `s3:GetObject`, `s3:PutObject`, `s3:DeleteObject` on the corresponding `KEY.tflock` object. It does not need DeleteObject on the state itself. Add `kms:Encrypt`, `kms:Decrypt`, `kms:GenerateDataKey` on the state key ARN (and DescribeKey if your tooling needs it). Bucket/key administrators and recovery operators should be separate from ordinary state writers. For migration/backup, additional permissions such as ListBucketVersions/GetObjectVersion may be required. See [HashiCorp S3 backend permissions](https://developer.hashicorp.com/terraform/language/backend/s3).

Bucket versioning is enabled with no automatic state-version expiration: recoverability is favored over speculative storage savings. No replication, S3 access-log archive or Object Lock is configured. Those require a separate audit/recovery architecture; an access log bucket should not be the same state bucket. Never force-unlock a state while another plan/apply is active. Protect plans like state; they can contain sensitive values.

## Operator network access

`private_access_cidrs` opens TCP 443 on the additional control-plane SG only to routed VPN/runner private addresses. Ensure return routing, DNS resolution and VPN authorization exist outside this project. Supplying a CIDR does not build connectivity. The simpler sandbox alternative is a fixed public `/32` in `public_access_cidrs`; private endpoint access stays enabled for nodes. Do not use GitHub-hosted runners for private Helm deployment without a deliberate connectivity design.

## Version promotion

Terraform CLI 1.13.4 is the tested minimum/CI version. AWS `~>6.38.0`, TLS `~>4.1.0`, Helm `~>3.1.0` constrain updates to reviewed minor families; committed per-root lock files select exact provider releases and include Linux/Windows checksums. Upgrades need PRs, lock updates, mocked tests, a sandbox apply and runtime evidence. Terraform lock files do not pin charts, add-on APIs or AMIs: the controller chart is explicitly 3.6.0; its vendored IAM policy is tied to app v3.6.0. Review chart release notes/CRD changes together with IAM changes. Helm upgrades do not automatically upgrade existing CRDs; apply reviewed upstream CRDs before upgrading a deployed controller if the release requires it.

EKS 1.35 is a deliberate minor choice, not a forever default. Confirm the target region's supported versions. Default compatible CNI/CoreDNS/kube-proxy builds are resolved via AWS API at plan time; freeze reviewed values in `addon_versions` for stable production promotion. Node groups follow the cluster minor and use an EKS-selected AL2023 x86_64 release on creation. Add `release_version` controls and a tested AMI promotion workflow before needing exact AMI reproducibility; do not assume an existing group automatically rolls to every new AMI build. Only choose x86_64 instance types with the current AMI.

Upgrade one Kubernetes minor at a time; check API removals, add-on compatibility and disruption budgets first. `max_unavailable=1` limits node rollout disruption, but one unavailable node out of two is substantial. Standard support avoids extended-support fees through eventual AWS auto-upgrade; schedule your own tested upgrade before support expiry. No cluster deletion protection is enabled for this disposable reference environment. Real production should add deletion protection and a change-management process.

## Runtime acceptance checklist (not executed during authoring)

- Plan/apply in the intended sandbox, verify no resources outside the dedicated naming/VPC scope.
- Verify all managed nodes Ready, AL2023/IMDSv2/encrypted disks, no public node IPs; verify CNI, DNS and pod networking in both AZs.
- Assume the allowed role and test Kubernetes authorization; verify an unauthorized role is denied. Test API reachability from approved/unapproved sources.
- Confirm all five control-plane log streams and VPC flow-log delivery; read encrypted entries to confirm KMS/delivery policies work.
- Check controller replicas/IRSA credentials/webhook reachability. Create an approved temporary HTTPS ingress, verify targets/health/SGs, remove it and verify AWS cleanup.
- Exercise node drain/rollout, single-AZ failure assumptions, state lock contention and state-version restore in an isolated test key.
- Test ordered teardown; record orphan checks, actual spend and all deviations in validation evidence.

## CI and review

CI is validation-only with read-only repository token permissions. No AWS OIDC token, saved AWS key or apply job exists. Paths isolate the project from the old EC2 example. A PR remains unmerged pending human review; check all CI findings and the explicit scanner exceptions. Organization-level branch protection/required reviewers are not configured by this project. Enable required review/checks through repository settings if desired.
