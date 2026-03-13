# provider.tf
provider "aws" {
  region = "ap-southeast-1"
  default_tags {
    tags = {
      Project   = "Epiq-Showcase-Kill-Switch"
      ManagedBy = "Terraform"
      Owner     = "Roger-Senior-DevOps"
    }
  }
}

# FinOps Kill-Switch: Send an SNS alert when we hit $8 (80% of $10)
resource "aws_budgets_budget" "epiq_limit" {
  name              = "epiq-monthly-budget"
  budget_type       = "COST"
  limit_amount      = "10"
  limit_unit        = "USD"
  time_unit         = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = ["your-email@example.com"] # CHANGE THIS
  }
}