# Task 20 — Required test evidence

The numbered tests below match Part A of the project brief (page 29). Results distinguish completed tests from configuration screenshots and untested behavior.

| # | Required test | Expected result | Current evidence / status |
|---:|---|---|---|
| 1 | Open the ALB DNS directly | `403 Forbidden` without the CloudFront origin header | Captured: `screenshots/13-cloudfront/13-alb-direct-403.png` |
| 2 | Open the CloudFront URL over HTTPS | Working page through CloudFront | **Blocked:** AWS account verification prevents distribution creation; no CloudFront distribution exists. |
| 3 | SSH to a private EC2 IP | Timeout; VPC Flow Logs show `REJECT` for port 22 | **Passed and captured:** SSH from tools to app-a timed out; the matching flow shows `REJECT` in `screenshots/15-network-tests/15-tools-ssh-app-timeout.png` and `screenshots/15-flowlogs/15-tools-to-app-ssh-reject.png`. |
| 4 | Connect to RDS port 3306 from a laptop | Timeout | **Passed and captured:** Chrome on the laptop opened the RDS endpoint at `:3306` and returned `ERR_CONNECTION_TIMED_OUT` in `screenshots/11-rds/11-laptop-to-rds-3306-timeout.png`. This is a TCP reachability check, not a MySQL-client handshake. |
| 5 | Connect to RDS port 3306 from an app EC2 instance | Successful connection | **TCP connection passed:** app-b reached RDS port 3306 in `screenshots/11-rds/11-app-b-to-rds-3306-reachable.png`. This proves network reachability, not an authenticated MySQL query. |
| 6 | Try to make an S3 object publicly readable | Block Public Access rejects the change/request | Block Public Access setting captured, but **refusal test** screenshot missing |
| 7 | Add an SSH `0.0.0.0/0` rule to the app security group | Lambda removes it and an SNS email arrives | Do only as a controlled test; before/after, Lambda log, and email screenshots missing |
| 8 | Stop nginx on one target | That target becomes unhealthy, the public page remains available, and alarm email arrives | Baseline 2/2 healthy captured; fault-injection/continuity/alarm evidence missing; public-page portion depends on CloudFront |
| 9 | Curl a private app IP from the tools instance | Page returned over VPC peering | **Passed and captured:** `screenshots/18-peering/18-tools-curl-app-success.png` shows the tools instance returning the app-a page. |
| 10 | Try deleting a recovery point from the locked vault | Denied by Vault Lock | Governance lock captured, but vault has zero backups; backup job and refusal test missing |

CloudTrail Event History and Flow Logs are required elsewhere in the brief, but they are **not** test 10. Do not enable the daily backup selection or run the recovery-point deletion test until the planned cleanup timing is clear: a retained recovery point can delay or prevent `terraform destroy`. Do not run the CloudFront success test until AWS Support resolves account verification.
