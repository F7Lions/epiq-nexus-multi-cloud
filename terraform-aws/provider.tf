# 1. Terraform Core Configuration (Backend & Providers)
terraform {
  # IM8: Remote state backend
  # Step 1: Run terraform apply (backend commented out)
  # Step 2: Uncomment this block and run terraform init -migrate-state
  backend "s3" {
    bucket         = "epiq-nexus-tfstate-f7lions"
    key            = "global/s3/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "epiq-nexus-tf-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# 2. AWS Provider Configuration
provider "aws" {
  region = "ap-southeast-1"
  default_tags {
    tags = {
      Project     = "Epiq-Showcase-Kill-Switch"
      ManagedBy   = "Terraform"
      Owner       = "Roger-Senior-DevOps"
      Environment = "UAT"
      Compliance  = "IM8"
    }
  }
}

# 3. FinOps Kill-Switch — alerts at 80% of $10 monthly budget
resource "aws_budgets_budget" "epiq_limit" {
  name         = "epiq-monthly-budget"
  budget_type  = "COST"
  limit_amount = "10"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["imraannico@gmail.com"]
  }
}