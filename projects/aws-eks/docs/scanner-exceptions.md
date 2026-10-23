# Resource-specific scanner exceptions

Checkov 3.2.495 runs with no global check skips and no soft-fail. Exceptions are inline on the affected resources, with reasons. These are accepted limitations of this portfolio baseline, not claims that controls are unnecessary in production.

| Check | Resource | Reason and production follow-up |
|---|---|---|
| CKV_AWS_339 | EKS cluster | Pinned scanner's `EKSPlatformVersion.py` hardcodes 1.25–1.33, so it rejects supported EKS 1.35. AWS [announced EKS 1.35 in January 2026](https://aws.amazon.com/about-aws/whats-new/2026/01/amazon-eks-distro-kubernetes-version-1-35/). A module validation and negative mocked test reject minors below the chosen 1.35 baseline. Verify [regional availability and support dates](https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html) before every deployment/upgrade. Remove this exception when the scanner's version model is current. |
| CKV_AWS_338 | Both encrypted log groups (via reusable module) | Thirty-day retention limits portfolio storage cost. Set retention according to incident/compliance requirements and remove the exception for a production profile. |
| CKV_AWS_18 | State bucket | No separate S3 access-log archive is provisioned. Production should centralize state-access auditing with an appropriate log destination and/or CloudTrail data-event policy. |
| CKV_AWS_144 | State bucket | Cross-region replication is absent from this single-region sandbox. Versioning is recovery assistance, not regional disaster recovery; design/test backup and replication separately. |
| CKV2_AWS_62 | State bucket | No state-object event consumer is part of the design; unused event notifications are not created. Add notifications only with a defined operator/automation purpose. |

The initial scan also found missing explicit KMS key policies and absent bucket lifecycle configuration. Those were fixed: keys explicitly delegate administration to account IAM, and the bucket aborts incomplete multipart uploads after seven days without expiring state history. See `validation.md` for the final scan counts.

The scanner runs offline (`skip-download`) with locally installed Terraform rules and no Prisma Cloud account, API key or remote module downloads. This avoids a network dependency for public guidance mappings; no claim is made about SaaS policy packs, cloud posture or deployed resources. A passing scan with exceptions does not prove complete security. The upstream controller IAM policy and AWS-managed IAM policies still warrant the review described in `security.md`.
