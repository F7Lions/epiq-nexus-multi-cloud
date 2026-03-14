# 1. The Web Application Firewall (WAFv2)
resource "aws_wafv2_web_acl" "epiq_waf" {
  name        = "epiq-web-firewall"
  description = "IM8 Compliant WAF for Epiq Discovery ALB"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "epiqWafMetrics"
    sampled_requests_enabled   = true
  }

  # Rule 1: Core Rule Set (Blocks common exploits like XSS)
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "epiqWafCommonRules"
      sampled_requests_enabled   = true
    }
  }

  # Rule 2: SQL Injection Protection
  rule {
    name     = "AWS-AWSManagedRulesSQLiRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "epiqWafSQLiRules"
      sampled_requests_enabled   = true
    }
  }
}

# 2. Attach the WAF to your existing Load Balancer
resource "aws_wafv2_web_acl_association" "epiq_waf_alb_attachment" {
  resource_arn = aws_lb.epiq_alb.arn
  web_acl_arn  = aws_wafv2_web_acl.epiq_waf.arn
}