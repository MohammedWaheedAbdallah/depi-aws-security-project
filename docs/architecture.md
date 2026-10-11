# Architecture

## VPCs and subnets

| VPC | CIDR | Subnet | CIDR | AZ | Type | Contents |
|---|---|---|---|---|---|---|
| `depi-sec-app-vpc` | `10.0.0.0/16` | `depi-sec-public-a` | `10.0.1.0/24` | `us-east-1a` | Public | ALB |
| same | same | `depi-sec-public-b` | `10.0.2.0/24` | `us-east-1b` | Public | ALB |
| same | same | `depi-sec-private-a` | `10.0.11.0/24` | `us-east-1a` | Private | EC2 A, RDS subnet, EFS mount target, SSM endpoints |
| same | same | `depi-sec-private-b` | `10.0.12.0/24` | `us-east-1b` | Private | EC2 B, RDS subnet, EFS mount target, SSM endpoints |
| `depi-sec-tools-vpc` | `10.1.0.0/16` | `depi-sec-tools-a` | `10.1.1.0/24` | `us-east-1a` | Private | Monitoring EC2 and SSM endpoints |

The private app route table has the VPC local route, an S3 gateway endpoint route, and a peering route to `10.1.0.0/16`. It has no NAT route. The public route table has the Internet Gateway default route.

## Request path

1. After CloudFront is enabled and created, a browser connects to the distribution over HTTPS.
2. CloudFront will send HTTP to the ALB and add the generated `X-Origin-Verify` header.
3. The ALB listener returns a fixed 403 unless that header matches. The matching rule forwards to the target group. Direct ALB access remains intentionally blocked by this listener, including while CloudFront creation is pending.
4. The target group sends traffic to EC2 A or B on port 80. The instances have no public IP and no inbound SSH rule.
5. EC2 reaches RDS on 3306 and EFS on 2049 through security-group references.

The tools instance reaches a private app IP over VPC peering. Both route tables contain the reciprocal peering route, and the app security group/NACL permit the test traffic.

## Administration path

The EC2 and tools instances use the `depi-sec-ec2-role` instance profile. Each VPC has `ssm`, `ssmmessages`, and `ec2messages` interface endpoints with Private DNS enabled. In both VPCs, Session Manager works without an internet route, public IP, SSH key, or port 22. The tools instance was rebooted once after its endpoints became available so its SSM Agent reconnected.

## Data and audit path

- S3 application and logs buckets use public-access blocking, versioning, AES-256 encryption, lifecycle rules, and an `aws:SecureTransport` deny policy.
- CloudTrail writes management and app-bucket data events to the logs bucket with log-file validation enabled.
- VPC Flow Logs write packet metadata to the CloudWatch log group `/depi-sec/vpc/flowlogs` with 14-day retention.
- CloudWatch also receives the CloudTrail log stream, five metric alarms, and the overview dashboard.
- AWS Backup can select resources tagged with the configured `Project` value. The new-account deployment keeps that selection disabled during the short-lived core test; it must be enabled deliberately for Task 19. A fresh deployment uses a Governance-mode vault lock, with a seven-day minimum retention.
