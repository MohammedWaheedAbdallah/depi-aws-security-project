# Security Controls

| Control | AWS resource | Threat stopped | Evidence to capture |
|---|---|---|---|
| Public/private separation | VPC route tables and subnet flags | Direct internet reachability to compute | Public and private route-table screens |
| CloudFront-only origin | ALB fixed 403 + secret-header listener rule | Bypassing CDN controls | CloudFront success and ALB 403 |
| Tiered firewall | `alb_sg`, `app_sg`, `db_sg`, `efs_sg` | Unauthorised lateral access | Inbound-rule screens with SG sources |
| Stateless second layer | Private NACL | Accidental SG exposure and SSH | NACL rule list |
| Private administration | SSM endpoints and EC2 role | SSH keys, public IPs, open port 22 | Session Manager shell and empty public-IP field |
| S3 public-access block | Two `aws_s3_bucket_public_access_block` resources | Accidental public bucket/object | Refused public-object attempt |
| HTTPS-only S3 | Bucket policy with `aws:SecureTransport = false` deny | Plain HTTP data access | Bucket policy JSON |
| Encryption | EBS gp3, EFS, RDS, S3 AES-256 | Data at rest exposure | Encrypted volume/RDS/EFS screens |
| Least privilege | EC2 role and S3 read policy | Broad server credentials | Role trust and policy JSON |
| Cost governance | Budget, IAM deny policy, automatic action | Cost abuse after threshold | Budget action screen |
| API audit | Multi-Region CloudTrail to S3 | Untraceable account changes | Trail configuration and event history |
| Network audit | VPC Flow Logs to CloudWatch Logs | Missing accepted/rejected metadata | `/depi-sec/vpc/flowlogs` REJECT record |
| Auto-remediation | EventBridge, Lambda, SNS | Public SSH/RDP rule left open | Before/after SG rule and email |
| Private connectivity | VPC peering and reciprocal routes | Public path between tools and app | Routes and successful curl |
| Recovery protection | AWS Backup Governance vault lock | Early backup deletion | Locked vault and refused deletion |

## CloudFront status

In a fresh deployment, enable CloudFront only after the core stack succeeds. The EventBridge rule in `lambda.tf` remains active because it triggers Lambda auto-remediation. CloudWatch log groups, metric filters, alarms, and dashboard are deployed with the core stack.
