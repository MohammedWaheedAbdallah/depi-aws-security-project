# Mini Project 1 — Secure AWS Web Platform (Terraform)

## 1. Project overview

This Terraform project builds a secure web platform in `us-east-1`.
Two private EC2 app servers sit behind an ALB, with private RDS and EFS storage.
Session Manager provides access without public instance IPs; a tools VPC connects by peering.
CloudTrail, Flow Logs, alarms, a budget, remediation, and backup are included.
CloudFront is the intended HTTPS entry point, but AWS account verification still blocks it; direct ALB access correctly returns 403.

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

## 5. Prerequisites

Terraform `>= 1.6`, AWS CLI, an authorized AWS profile with permissions for the services in this project, and a confirmed alert email. Use `us-east-1` and keep state, `.tfvars`, plans, and credentials out of Git.

## 6. How to deploy

From `deployments/new-account`, copy `terraform.tfvars.example` to `terraform.tfvars` and set `expected_account_id`, `alert_email`, and `owner`. Select the matching AWS profile and confirm the account ID with `aws sts get-caller-identity` before running `terraform init`, `terraform plan`, and `terraform apply`. Confirm the SNS email. CloudFront is disabled by default until AWS permits distribution creation.

## 7. How to verify

The ten required tests, actual results, and evidence are in [docs/testing.md](docs/testing.md):

1. Direct ALB request: 403 — captured.
2. CloudFront HTTPS page: blocked by AWS account verification.
3. SSH to private EC2: timeout and Flow Logs `REJECT` — captured from the tools instance.
4. Laptop to RDS: timeout — captured.
5. App server to RDS: TCP/3306 connection — captured; MySQL login not tested.
6. Public S3 object attempt: refused by Block Public Access — captured.
7. Public SSH rule: Lambda removed it within a minute; SNS email received — captured.
8. Stop nginx on app-a: target became unhealthy, ALB still returned HTTP 200 through app-b, and alarm email arrived — captured. CloudFront HTTPS remains unavailable.
9. Tools VPC to app server: page returned — captured.
10. Locked-vault recovery-point deletion: refused — captured. The test backup was then removed and the Governance lock restored.

## 8. Screenshots

Screenshots are grouped by task. Each caption describes what the image shows; missing evidence is listed in the [test results](docs/testing.md).

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
| [S3 public attempt refused](screenshots/10-s3/10-s3-public-attempt-refused.png) | Console refused to make the test object public. |
| [Encrypted RDS](screenshots/11-rds/11-rds-encrypted.png) | MySQL RDS instance is Available and storage encryption is enabled. |
| [RDS internet gateway disabled](screenshots/11-rds/11-rds-internet-gateway-disabled.png) | RDS connectivity page shows Internet access gateway Disabled. |
| [RDS not public](screenshots/11-rds/11-rds-not-publicly-accessible.png) | RDS form shows Not publicly accessible selected; no modification was made. |
| [App-to-RDS TCP reachability](screenshots/11-rds/11-app-b-to-rds-3306-reachable.png) | App-b can open TCP/3306 to RDS; this is not a MySQL login test. |
| [Laptop-to-RDS timeout](screenshots/11-rds/11-laptop-to-rds-3306-timeout.png) | Browser on the laptop times out connecting to the RDS endpoint at TCP/3306. |
| [Two healthy ALB targets](screenshots/12-alb/12-alb-two-healthy-targets.png) | Target group baseline: two registered targets Healthy. |
| [ALB fault-injection overview](screenshots/12-alb/12-alb-one-unhealthy-during-test.png) | Target-group summary during the controlled nginx outage: one target Healthy, one Unhealthy. |
| [One unhealthy ALB target](screenshots/12-alb/12-alb-target-health-detail.png) | During the controlled nginx stop, app-a was Unhealthy while app-b stayed Healthy. |
| [Direct ALB 403](screenshots/13-cloudfront/13-alb-direct-403.png) | Direct ALB request returns the expected Forbidden message. |
| [ALB listener rules](screenshots/13-cloudfront/13-alb-listener-rules.png) | Matching origin-verification header forwards; default rule returns 403. Header value masked. |
| [CloudTrail logging](screenshots/14-cloudtrail/14-cloudtrail-trail-logging.png) | Multi-region trail is Logging to its S3 bucket. |
| [CloudTrail event identity](screenshots/14-cloudtrail/14-cloudtrail-create-event-identity-ip-time.png) | CreateTrail event includes user identity, source IP, and timestamp. |
| [SSH flow REJECT](screenshots/15-flowlogs/15-tools-to-app-ssh-reject.png) | Tools-to-app TCP/22 flow was rejected. |
| [SSH timeout](screenshots/15-network-tests/15-tools-ssh-app-timeout.png) | SSH from tools to app-a timed out. |
| [Initial CloudWatch alarm states](screenshots/16-monitoring/16-five-alarms-states.png) | Initial alarm states before monitoring fixes and metric data arrived. |
| [CPU alarm SNS action](screenshots/16-monitoring/16-cpu-alarm-sns-action.png) | CPU alarm is OK and configured to notify the `depi-sec-alerts` SNS topic. |
| [ALB unhealthy alarm](screenshots/16-monitoring/16-alb-unhealthy-alarm.png) | CloudWatch entered ALARM after app-a failed health checks. |
| [ALB alarm email](screenshots/16-monitoring/16-alb-alarm-email.png) | SNS delivered the ALB alarm email. Account ID masked. |
| [Lambda EventBridge trigger](screenshots/17-automation/17-lambda-eventbridge-trigger.png) | Remediation Lambda has an EventBridge trigger. |
| [Ingress event pattern](screenshots/17-automation/17-eventbridge-authorize-ingress-pattern.png) | Enabled EventBridge rule matches `AuthorizeSecurityGroupIngress`. |
| [Temporary public SSH rule](screenshots/17-automation/17-ssh-rule-added.png) | Controlled test briefly added TCP/22 from `0.0.0.0/0` to the private app SG. |
| [SSH rule removed](screenshots/17-automation/17-ssh-rule-auto-removed.png) | Lambda removed the temporary rule; only the three original inbound rules remain. |
| [Remediation email](screenshots/17-automation/17-remediation-sns-email.png) | SNS confirmed removal of the public SSH rule. Address and unsubscribe link masked. |
| [VPC Flow Log active](screenshots/17-testing/17-vpc-flow-log-active.png) | VPC Flow Log is active and sends events to CloudWatch Logs. |
| [General port-22 rejects](screenshots/17-testing/17-vpc-port22-rejects.png) | Log query shows port-22 rejects; the exact tools-to-app flow is shown above. |
| [VPC peering](screenshots/18-peering/18-peering-active-route-tables.png) | Peering connection is Active and referenced by route tables in both VPCs. |
| [Tools-side peering route](screenshots/18-peering/18-tools-route-to-app-vpc.png) | Tools subnet routes `10.0.0.0/16` through the active peering connection. |
| [Tools-to-app curl](screenshots/18-peering/18-tools-curl-app-success.png) | HTTP from tools to app-a returned the application page over peering. |
| [Governance vault lock](screenshots/19-backup/19-backup-governance-lock.png) | Backup vault lock is in Governance mode. |
| [Test recovery point](screenshots/19-backup/19-backup-recovery-point-locked.png) | A completed test EBS recovery point was inside the locked vault. |
| [Deletion refused](screenshots/19-backup/19-backup-delete-denied.png) | AWS refused to delete that recovery point while the vault was locked. |
| [Daily backup rule](screenshots/19-backup/19-backup-daily-rule.png) | Plan has a daily rule and 30-day retention; scheduled selection is disabled. |

## 9. Cost notes

ALB, EC2, RDS, EFS, and interface endpoints incur charges while running. The $10 budget is an alert, not a spending cap. A card charge of about $11 was reported on 12 October; Cost Explorer had not yet attributed it by service. The final total remains pending billing refresh and cleanup.

## 10. How to destroy

Save final screenshots first. Empty both versioned S3 buckets, review any locked backup recovery points, then check the destroy plan from `deployments/new-account` with the correct AWS profile:

```powershell
cd .\deployments\new-account
terraform plan -destroy -out destroy.tfplan
terraform apply destroy.tfplan
```

After applying the reviewed plan, confirm the Console is empty and record the actual Cost Explorer total when billing data appears. A locked backup recovery point can prevent vault deletion and must be reviewed before destroying. Cleanup has **not** been run yet.

## 11. What I learned

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

- CloudFront creation failed with AWS account-verification `AccessDenied` on 11 October 2026; no distribution exists.
- CloudFront test 2 and its required screenshot are blocked by AWS account verification. The public HTTPS portion of test 8 cannot be shown without CloudFront; ALB failover and alerting were verified.
- Infrastructure cleanup and the final Cost Explorer total are pending. The temporary Backup recovery point and S3 test object were removed; the Backup Governance lock was restored.
- The ALB origin currently uses HTTP, and Terraform state is local. Production would require HTTPS to the origin and encrypted remote state.
