output "alb_dns_name" {
  value = module.project.alb_dns_name
}

output "cloudfront_domain_name" {
  value = module.project.cloudfront_domain_name
}

output "app_bucket_name" {
  value = module.project.app_bucket_name
}

output "logs_bucket_name" {
  value = module.project.logs_bucket_name
}

output "rds_endpoint" {
  value = module.project.rds_endpoint
}

output "app_a_private_ip" {
  value = module.project.app_a_private_ip
}

output "app_b_private_ip" {
  value = module.project.app_b_private_ip
}

output "tools_private_ip" {
  value = module.project.tools_private_ip
}
