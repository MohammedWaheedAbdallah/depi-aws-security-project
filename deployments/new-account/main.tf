variable "expected_account_id" {
  type        = string
  description = "The only AWS account this deployment may manage"

  validation {
    condition     = can(regex("^[0-9]{12}$", var.expected_account_id))
    error_message = "Enter the new 12-digit AWS account ID."
  }
}

variable "alert_email" {
  type        = string
  description = "Address receiving budget and security alerts"
}

variable "owner" {
  type        = string
  description = "Honest owner/team label for AWS resource tags"
}

variable "project_name" {
  type    = string
  default = "depi-mini-project-1"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "enable_cloudfront" {
  type        = bool
  description = "Turn on only after the core deployment and account checks succeed"
  default     = false
}

variable "enable_scheduled_backups" {
  type        = bool
  description = "Turn on only for the controlled AWS Backup test"
  default     = false
}

module "project" {
  source                   = "../../terraform"
  expected_account_id      = var.expected_account_id
  alert_email              = var.alert_email
  owner                    = var.owner
  project_name             = var.project_name
  region                   = var.region
  enable_cloudfront        = var.enable_cloudfront
  enable_scheduled_backups = var.enable_scheduled_backups
}
