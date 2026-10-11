# Mini Project 1 — Secure AWS Web Platform (Terraform)

## 1. Project overview

This repository builds the DEPI Mini Project 1 platform with Terraform in `us-east-1`.
The intended public entry point is CloudFront; its creation is currently blocked by AWS account verification. A guarded Terraform retry on 11 October 2026 returned `403 AccessDenied` (AWS Request ID `2b579a67-d9db-46f1-a0ac-a382b36366b6`). The ALB, EC2 servers, RDS, and EFS are deployed in the VPC design described below, and direct ALB access returns the intended 403 response.
There are no SSH keys and no public IP addresses on compute resources; Session Manager uses private VPC endpoints.
S3 buckets are private, encrypted, versioned, and protected by transport-security policies.
CloudTrail, VPC Flow Logs, EventBridge/Lambda remediation, peering, and AWS Backup are included.

For a fresh AWS account, deploy from `deployments/new-account` with a separate state and an explicit account-ID guard. Start with CloudFront disabled, then enable it after the core stack works. CloudWatch monitoring remains enabled throughout.

## 2. Architecture diagram

```text
Internet -> CloudFront (HTTPS) -> ALB (public subnets)
                                  X-Origin-Verify header required
                                  -> EC2 A/B (private subnets)
                                  -> RDS MySQL / EFS (private subnets)

Tools VPC (10.1.0.0/16) -- VPC peering --> App VPC (10.0.0.0/16)
CloudTrail -> private S3 logs bucket + CloudWatch Logs
VPC Flow Logs -> CloudWatch Logs (`/depi-sec/vpc/flowlogs`)
CloudTrail event -> EventBridge -> Lambda -> SNS email (SSH/RDP auto-remediation)
EC2/EFS/RDS -> AWS Backup vault (Governance lock in a fresh deployment)
```

See [docs/architecture.md](docs/architecture.md) for the full traffic path and subnet placement.

## 3. Network design table

| VPC | Subnet | CIDR | AZ | Type | Main resources |
|---|---|---|---|---|---|
| app-vpc | public-a | 10.0.1.0/24 | us-east-1a | Public | ALB |
| app-vpc | public-b | 10.0.2.0/24 | us-east-1b | Public | ALB |
| app-vpc | private-a | 10.0.11.0/24 | us-east-1a | Private | EC2, RDS, EFS endpoint |
| app-vpc | private-b | 10.0.12.0/24 | us-east-1b | Private | EC2, RDS, EFS endpoint |
| tools-vpc | tools-a | 10.1.1.0/24 | us-east-1a | Private | Monitoring EC2 and SSM endpoints |

The public route table has `0.0.0.0/0` to the Internet Gateway. The private app route table has only the local route plus the S3 gateway endpoint and peering route; there is no NAT Gateway.

## 4. Security controls table

| Control | Service/resource | What it stops |
|---|---|---|
| Tiered ingress | ALB/app/DB/EFS security groups | Direct internet access to private tiers |
| CloudFront origin verification | Secret header and ALB listener rule | ALB bypass; direct ALB request returns 403 |
| No SSH | No key pair, no port 22 SG rule, NACL deny | Interactive SSH from the internet |
| Private administration | SSM interface endpoints and EC2 role | Public IPs and long-lived server keys |
| Data protection | S3 encryption/versioning, EBS gp3 encryption, EFS encryption, RDS encryption | Data exposure and unencrypted storage |
| Transport security | S3 `aws:SecureTransport` deny policies | HTTP access to buckets |
| Cost guardrail | $10 budget and automatic IAM deny action | Expensive EC2/RDS creation after threshold |
| API audit | Multi-Region CloudTrail to S3 | Unrecorded account changes |
| Network audit | VPC Flow Logs to CloudWatch Logs | Missing accepted/rejected packet metadata |
| Auto-remediation | EventBridge + least-privilege Lambda + SNS | Public SSH/RDP rules left open |
| Backup immutability | AWS Backup Governance vault lock | Early recovery-point deletion |

CloudWatch metric alarms, dashboard, CloudTrail logs, and VPC Flow Logs are managed by Terraform. The CloudFront test requires a successful second-stage apply.

## 5. Prerequisites

- Terraform `>= 1.6` and AWS provider `~> 5.0`.
- AWS CLI temporary-credential profile configured for the new account and `us-east-1`.
- Permissions to manage IAM, VPC, EC2, ALB, CloudFront, S3, RDS, EFS, CloudTrail, EventBridge, Lambda, AWS Backup, Budgets, and Secrets Manager.
- A confirmed email address for the budget and SNS subscriptions.
- An activated account with a verified payment method and the account owner's permission to run billable resources.
- Never commit `terraform.tfstate`, plans, credentials, or `.tfvars` files.

## 6. How to deploy

Follow the complete [new-account deployment guide](docs/new-account-deployment.md). Run Terraform only from `deployments/new-account`, never from `terraform/` for the fresh account. The guide covers profile setup, account verification, the core plan, CloudFront, testing, and cleanup. The saved state and plans under `terraform/` belong to a different deployment and must not be imported or reused.

Confirm the SNS email subscription after apply. The budget action may attach a deny policy to the developer group after the threshold, but it is **not** a spending cap or an automatic resource shutdown.

## 7. How to verify

Run the tests in [docs/testing.md](docs/testing.md). The most important expected results are:

1. CloudFront URL loads over HTTPS; the ALB DNS name returns 403.
2. EC2 instances have no public IP and open in Session Manager.
3. A file written through EFS on server A is visible on server B.
4. RDS is not publicly accessible but accepts port 3306 from the app SG.
5. S3 public access and insecure transport attempts are refused.
6. Adding `0.0.0.0/0:22` to the app SG is removed by Lambda and produces an SNS message.
7. The tools-VPC instance curls a private app-server IP through the peering connection.
8. Backup vault lock refuses early recovery-point deletion.
9. CloudWatch dashboard receives metrics and the alarm email path can be tested.

If CloudFront returns an account-verification 403, preserve the error and ask AWS Support to verify the **new** account. Do not bypass the restriction. CloudWatch dashboard and alarm tests can be performed before CloudFront is enabled.

## 8. Screenshots

The following are **redacted copies** from the new account, organized by task. Click each filename for the full image. Each caption states only what that screenshot visibly proves; the [evidence review](docs/evidence-review-2026-10-10.md) lists the missing tests. Original images were preserved and must not be uploaded unredacted.

| Screenshot | Caption |
|---|---|
| [Budget overview](screenshots/02-budget/02-budget-overview.png) | $10 monthly budget with a standby budget action. |
| [Budget email confirmation](screenshots/02-budget/02-budget-email-confirmed.png) | Budget recipient verified; email address masked. |
| [Budget IAM action](screenshots/02-budget/02-budget-iam-policy-action.png) | Standby budget action targets the developer group with the deny policy. |
| [EC2 role trust](screenshots/03-iam/03-iam-ec2-role-trust.png) | EC2 service principal is trusted to assume the instance role. |
| [S3 read policy](screenshots/03-iam/03-iam-s3-read-policy-summary.png) | Customer-managed IAM policy summary shows limited S3 read access. |
| [S3 read policy JSON](screenshots/03-iam/03-iam-s3-read-policy-json.png) | Policy grants only S3 GetObject on the application bucket. |
| [Policy attached to role](screenshots/03-iam/03-iam-s3-read-policy-attached-role.png) | S3 read policy is attached to the EC2 role. |
| [Public route](screenshots/04-vpc/04-vpc-public-route.png) | App-VPC public route table sends `0.0.0.0/0` to the Internet Gateway. |
| [Private route](screenshots/04-vpc/04-vpc-private-route.png) | App-VPC private route table shows local, S3 endpoint and peering destinations. |
| [App VPC resource map](screenshots/04-vpc/04-vpc-app-resource-map.png) | App VPC map shows subnet and route-table layout. |
| [App ingress](screenshots/05-sg/05-sg-app-ingress.png) | App SG permits HTTP from the ALB SG and tools CIDR. |
| [DB ingress](screenshots/05-sg/05-sg-db-ingress.png) | DB SG permits MySQL 3306 from the app SG. |
| [EFS ingress](screenshots/05-sg/05-sg-efs-ingress.png) | EFS SG permits NFS 2049 from the app SG. |
| [NACL subnet associations](screenshots/06-nacl/06-nacl-private-subnet-associations.png) | Custom NACL is associated with two private app subnets. |
| [NACL outbound](screenshots/06-nacl/06-nacl-outbound-rules.png) | Outbound NACL allow rules and default deny are visible. |
| [NACL SSH deny](screenshots/06-nacl/06-nacl-inbound-ssh-deny.png) | Inbound NACL explicitly denies SSH port 22. |
| [Available endpoints](screenshots/07-endpoints/07-endpoints-available.png) | Six interface endpoints and one S3 gateway endpoint are Available. |
| [No public IPv4](screenshots/08-session-manager/08-ec2-no-public-ip.png) | All three EC2 instances are running without public IPv4 addresses. |
| [Session Manager shell](screenshots/08-session-manager/08-ssm-shell-hostname.png) | Private app instance responds to `hostname` through Session Manager. |
| [Encrypted EFS](screenshots/09-efs/09-efs-encrypted.png) | EFS file system is Available and encrypted. |
| [EFS mount targets](screenshots/09-efs/09-efs-two-available-mount-targets.png) | Two mount targets are Available. |
| [Shared file on app-a](screenshots/09-efs/09-efs-shared-file-app-a.png) | App-a has `nfs4` mounted and reports the shared file's SHA-256. |
| [Shared file on app-b](screenshots/09-efs/09-efs-shared-file-app-b.png) | App-b reports the same file and SHA-256. |
| [Encrypted EBS volumes](screenshots/09-efs/09-ebs-encrypted-volumes.png) | All three attached EC2 volumes show Encryption: Encrypted. |
| [gp3 EBS volumes](screenshots/09-efs/09-ebs-gp3-volumes.png) | The three EC2 volumes are gp3. |
| [S3 Block Public Access](screenshots/10-s3/10-s3-block-public-access.png) | Application bucket has Block All Public Access On. |
| [Encrypted RDS](screenshots/11-rds/11-rds-encrypted.png) | MySQL RDS instance is Available and storage encryption is enabled. |
| [RDS internet gateway disabled](screenshots/11-rds/11-rds-internet-gateway-disabled.png) | RDS connectivity page shows Internet access gateway Disabled. |
| [RDS not public](screenshots/11-rds/11-rds-not-publicly-accessible.png) | RDS form shows Not publicly accessible selected; no modification was made. |
| [App-to-RDS TCP reachability](screenshots/11-rds/11-app-b-to-rds-3306-reachable.png) | App-b can open TCP/3306 to RDS; this is not a MySQL login test. |
| [Laptop-to-RDS timeout](screenshots/11-rds/11-laptop-to-rds-3306-timeout.png) | Browser on the laptop times out connecting to the RDS endpoint at TCP/3306. |
| [Two healthy ALB targets](screenshots/12-alb/12-alb-two-healthy-targets.png) | Target group baseline: two registered targets Healthy. |
| [Direct ALB 403](screenshots/13-cloudfront/13-alb-direct-403.png) | Direct ALB request returns the expected Forbidden message. |
| [ALB listener rules](screenshots/13-cloudfront/13-alb-listener-rules.png) | Matching origin-verification header forwards; default rule returns 403. Header value masked. |
| [CloudTrail logging](screenshots/14-cloudtrail/14-cloudtrail-trail-logging.png) | Multi-region trail is Logging to its S3 bucket. |
| [CloudTrail event identity](screenshots/14-cloudtrail/14-cloudtrail-create-event-identity-ip-time.png) | CreateTrail event includes user identity, source IP, and timestamp. |
| [SSH flow REJECT](screenshots/15-flowlogs/15-tools-to-app-ssh-reject.png) | Tools-to-app TCP/22 flow was rejected. |
| [SSH timeout](screenshots/15-network-tests/15-tools-ssh-app-timeout.png) | SSH from tools to app-a timed out; an outside-laptop test is still missing. |
| [CloudWatch alarm states](screenshots/16-monitoring/16-five-alarms-states.png) | Five alarms exist; three remain in Insufficient data state. |
| [CPU alarm SNS action](screenshots/16-monitoring/16-cpu-alarm-sns-action.png) | CPU alarm is OK and configured to notify the `depi-sec-alerts` SNS topic. |
| [Lambda EventBridge trigger](screenshots/17-automation/17-lambda-eventbridge-trigger.png) | Remediation Lambda has an EventBridge trigger; no live remediation test yet. |
| [Ingress event pattern](screenshots/17-automation/17-eventbridge-authorize-ingress-pattern.png) | Enabled EventBridge rule matches `AuthorizeSecurityGroupIngress`. |
| [VPC Flow Log active](screenshots/17-testing/17-vpc-flow-log-active.png) | VPC Flow Log is active and sends events to CloudWatch Logs. |
| [General port-22 rejects](screenshots/17-testing/17-vpc-port22-rejects.png) | Log query shows port-22 rejects; the exact tools-to-app flow is shown above. |
| [VPC peering](screenshots/18-peering/18-peering-active-route-tables.png) | Peering connection is Active and referenced by route tables in both VPCs. |
| [Tools-side peering route](screenshots/18-peering/18-tools-route-to-app-vpc.png) | Tools subnet routes `10.0.0.0/16` through the active peering connection. |
| [Tools-to-app curl](screenshots/18-peering/18-tools-curl-app-success.png) | HTTP from tools to app-a returned the application page over peering. |
| [Governance vault lock](screenshots/19-backup/19-backup-governance-lock.png) | Backup vault lock is in Governance mode; there are zero recovery points so far. |
| [Daily backup rule](screenshots/19-backup/19-backup-daily-rule.png) | Plan has a daily rule and 30-day retention; no completed backup is proved. |

## 9. Cost notes

The ALB and interface endpoints are billable while they exist. CloudFront, RDS, EFS, backup storage, and S3 can also incur charges. Check Cost Explorer and Bills during testing and after cleanup; the $10 budget only alerts and applies the specified IAM policy. The current RDS screenshot shows MySQL 8.0.46 with Extended Support enabled: [AWS lists 1 August 2026 as the start of its extra-support pricing](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/MySQL.Concepts.VersionMgmt.html), so check the actual bill promptly. The configuration adds three SSM endpoints to the tools VPC so the monitoring instance can use Session Manager privately. The private NACL includes an ephemeral return rule for S3 gateway-endpoint traffic while retaining the explicit SSH deny.

## 10. How to destroy

Take final screenshots before cleanup. From `deployments/new-account`, stop new backup selections if necessary, review any S3 object versions and recovery points, and inspect the destroy plan carefully:

```powershell
cd .\deployments\new-account
terraform plan -destroy -out destroy.tfplan
terraform apply destroy.tfplan
```

Use the account guard and profile checks in the [deployment guide](docs/new-account-deployment.md) before any destroy. A versioned S3 bucket or locked backup vault may prevent a complete destroy; inspect the exact error and remaining resources rather than removing state entries. Check the console for ALB, EC2, RDS, EFS mount targets, endpoints, CloudFront, and S3 remnants.

## 11. What I learned

Draft reflection prompts based on this build; **rewrite them in your own words before submission** as the brief requires:

1. I learned that Terraform makes the network, identity, storage, and recovery design repeatable.
2. I learned that a subnet is public because of its route to an Internet Gateway, not its name.
3. I learned that security groups are stateful while NACLs require explicit return-path rules.
4. I learned that an EC2 role avoids putting long-lived access keys on instances.
5. I learned that private SSM endpoints permit administration without public IPs or a NAT Gateway.
6. I learned that a secret origin header can make direct ALB requests fail, while CloudFront account verification is a separate deployment dependency.
7. I learned that S3 Block Public Access and IAM permissions protect different parts of the access path.
8. I learned that CloudTrail logs API identity and activity, while Flow Logs record network-flow metadata.
9. I learned that EventBridge and Lambda can remove a risky security-group rule, but the remediation must be tested end to end.
10. I learned that a locked backup vault and database version choices have operational and cost consequences during cleanup.

## 12. Known limitations

- CloudFront creation depends on AWS Support verifying CloudFront access for the new account; the 11 October retry still failed with `AccessDenied` and created no distribution.
- The ALB origin uses HTTP inside AWS; production should use HTTPS to the origin as well.
- The Terraform configuration deliberately selects the standard Amazon Linux 2023 image rather than the Minimal image, because the standard image includes the SSM Agent required for private Session Manager access.
- Local state contains sensitive values such as the generated database password. It is ignored by Git for this lab; production should use encrypted remote state with locking.
- Terraform local state and saved plans can contain sensitive values. The fresh-account root keeps its state separate from `terraform/`; use encrypted remote state with locking for production.
