terraform {
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.0" }
  }
  required_version = ">= 1.6"
}

provider "aws" {
  region              = var.region
  allowed_account_ids = [var.expected_account_id]
  default_tags {
    tags = {
      Project     = var.project_name
      Owner       = var.owner
      Environment = "lab"
      ManagedBy   = "terraform"
    }
  }
}
