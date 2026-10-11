variable "project_name" {
  type        = string
  description = "Project tag applied to every resource"
  default     = "depi-mini-project-1"
}

variable "owner" {
  type        = string
  description = "Name used in the required Owner tag"
  default     = "Project Team"
}

variable "expected_account_id" {
  type        = string
  description = "AWS account ID that Terraform is allowed to manage"

  validation {
    condition     = can(regex("^[0-9]{12}$", var.expected_account_id))
    error_message = "expected_account_id must be a 12-digit AWS account ID."
  }
}

variable "region" {
  type        = string
  description = "AWS region used by the whole project"
  default     = "us-east-1"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR for the application VPC"
  default     = "10.0.0.0/16"
}

variable "tools_vpc_cidr" {
  type        = string
  description = "CIDR for the private tools VPC"
  default     = "10.1.0.0/16"
}

variable "alert_email" {
  type        = string
  description = "Email for budget and Lambda notifications"
}

variable "enable_cloudfront" {
  type        = bool
  description = "Deploy CloudFront; set false only if AWS still blocks distribution creation"
  default     = true
}

variable "enable_scheduled_backups" {
  type        = bool
  description = "Attach tagged resources to the daily backup plan; disable during short-lived labs to avoid unattended recovery points"
  default     = true
}
