output "alb_dns_name" {
  description = "ALB DNS Name (Should return 403 directly)"
  value       = aws_lb.alb.dns_name
}

output "app_bucket_name" {
  description = "Private application S3 bucket"
  value       = aws_s3_bucket.app_bucket.bucket
}

output "logs_bucket_name" {
  description = "Private logs S3 bucket"
  value       = aws_s3_bucket.logs_bucket.bucket
}

output "rds_endpoint" {
  description = "Private RDS endpoint for the in-VPC connectivity test"
  value       = aws_db_instance.mysql.address
}

output "app_a_private_ip" {
  description = "Private IP for the app-A connectivity tests"
  value       = aws_instance.app_a.private_ip
}

output "app_b_private_ip" {
  description = "Private IP for the app-B connectivity tests"
  value       = aws_instance.app_b.private_ip
}

output "tools_private_ip" {
  description = "Private IP for the monitoring instance"
  value       = aws_instance.tools.private_ip
}
