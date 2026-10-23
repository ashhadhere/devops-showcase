# Running-cost model

Planning estimate for continuous **730-hour** use in us-east-1, low traffic, standard EKS support, two on-demand t3.medium nodes and one public NAT. This is a rough estimate, not a verified bill or binding current-rate quote.

| Item | Illustrative monthly allowance |
|---|---:|
| EKS standard-support control plane | ~$73 |
| Two t3.medium Linux on-demand instances | ~$61 |
| One NAT fixed hourly cost | ~$33 |
| NAT public IPv4 address | ~$4 |
| Two 30 GiB gp3 root disks | ~$5 |
| Four customer KMS keys (three platform/log keys plus state key) | ~$4 plus requests |
| Low-volume CloudWatch/S3/transfer and variability allowance | ~$0–70+ |

Round to **$180–250/month before tax**, excluding application load balancers, substantial log ingestion/retention, NAT processing, cross-AZ transfer, CPU surplus credits, persistent disks, VPN/runner, AWS support and additional nodes. Traffic can make this materially higher. S3 gateway endpoints have no interface-endpoint hourly fleet cost, but normal service/storage/request/transfer charges can apply. The controller alone creates no ALB.

Per-AZ NAT adds another NAT hourly/public-IP cost for the default two-AZ layout; it can reduce cross-AZ routing but raises fixed cost. Spot worker pools can lower compute cost with interruption risk; keep critical system capacity on demand. Savings Plans require a commitment and are not a good default for a short-lived portfolio demo.

Check [AWS EKS pricing](https://aws.amazon.com/eks/pricing/), [EC2 on-demand pricing](https://aws.amazon.com/ec2/pricing/on-demand/), [VPC NAT/IPv4 pricing](https://aws.amazon.com/vpc/pricing/), [EBS pricing](https://aws.amazon.com/ebs/pricing/), [KMS pricing](https://aws.amazon.com/kms/pricing/) and [AWS Pricing Calculator](https://calculator.aws/) immediately before deployment. Configure an AWS Budget and cost-allocation tags in your account. The architecture has no automatic idle shutdown. Scaling nodes to zero would still leave the EKS control plane/NAT running and remove controller capacity; destroy the environment after the demonstration instead.
