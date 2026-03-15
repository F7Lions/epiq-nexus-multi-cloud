# ==========================================
# AMAZON OPENSEARCH (NLP Query Engine)
# IM8: Private domain, encrypted at rest
# ==========================================

# Security Group for OpenSearch
resource "aws_security_group" "opensearch_sg" {
  name        = "epiq-opensearch-sg"
  description = "IM8: OpenSearch domain - ECS ingress only"
  vpc_id      = module.vpc.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  ingress {
    description     = "IM8: HTTPS from ECS only"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.ecs_sg.id]
  }

  egress {
    description = "IM8: Allow outbound within VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
}

# OpenSearch Domain
resource "aws_opensearch_domain" "epiq_search" {
  domain_name    = "epiq-discovery"
  engine_version = "OpenSearch_2.11"

  # FinOps: Minimum viable instance for showcase
  cluster_config {
    instance_type  = "t3.small.search"
    instance_count = 1
  }

  # IM8: Encryption at rest
  encrypt_at_rest {
    enabled = true
  }

  # IM8: Encryption in transit
  node_to_node_encryption {
    enabled = true
  }

  # IM8: HTTPS only
  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  # IM8: Private VPC deployment
  vpc_options {
    subnet_ids         = [module.vpc.private_subnets[0]]
    security_group_ids = [aws_security_group.opensearch_sg.id]
  }

  # IM8: Audit logs to CloudWatch
  log_publishing_options {
    cloudwatch_log_group_arn = aws_cloudwatch_log_group.opensearch_logs.arn
    log_type                 = "AUDIT_LOGS"
    enabled                  = true
  }

  # FinOps: Single AZ for showcase
  ebs_options {
    ebs_enabled = true
    volume_size = 10
    volume_type = "gp3"
  }

  advanced_security_options {
    enabled                        = true
    anonymous_auth_enabled         = false
    internal_user_database_enabled = false

    master_user_options {
      master_user_arn = aws_iam_role.ecs_execution_role.arn
    }
  }

  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = aws_iam_role.ecs_execution_role.arn }
      Action    = "es:*"
      Resource  = "arn:aws:es:ap-southeast-1:${data.aws_caller_identity.current.account_id}:domain/epiq-discovery/*"
    }]
  })

  tags = {
    Purpose = "NLP Query Engine for Epiq Discovery"
  }
}

# CloudWatch Log Group for OpenSearch Audit Logs
resource "aws_cloudwatch_log_group" "opensearch_logs" {
  name              = "/aws/opensearch/epiq-discovery"
  retention_in_days = 30
}

# CloudWatch Log Resource Policy
resource "aws_cloudwatch_log_resource_policy" "opensearch_logs" {
  policy_name = "epiq-opensearch-log-policy"
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "es.amazonaws.com"
      }
      Action = [
        "logs:PutLogEvents",
        "logs:CreateLogStream"
      ]
      Resource = "${aws_cloudwatch_log_group.opensearch_logs.arn}:*"
    }]
  })
}

# IAM Policy for ECS to query OpenSearch
resource "aws_iam_policy" "ecs_opensearch_policy" {
  name        = "epiq-ecs-opensearch-policy"
  description = "IM8: Least-privilege OpenSearch access for ECS tasks"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "OpenSearchAccess"
      Effect = "Allow"
      Action = [
        "es:ESHttpGet",
        "es:ESHttpPost",
        "es:ESHttpPut",
        "es:DescribeElasticsearchDomain",
        "es:DescribeDomain"
      ]
      Resource = "arn:aws:es:ap-southeast-1:${data.aws_caller_identity.current.account_id}:domain/epiq-discovery/*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_opensearch_attach" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = aws_iam_policy.ecs_opensearch_policy.arn
}

# Output for app configuration
output "opensearch_endpoint" {
  value       = aws_opensearch_domain.epiq_search.endpoint
  description = "OpenSearch domain endpoint for ECS app configuration"
}