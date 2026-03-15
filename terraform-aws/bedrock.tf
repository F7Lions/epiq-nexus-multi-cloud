# ==========================================
# AMAZON BEDROCK (GenAI Copilot)
# IM8: IAM-controlled, VPC endpoint access
# ==========================================

# VPC Endpoint for Bedrock - keeps traffic private
resource "aws_vpc_endpoint" "bedrock" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.ap-southeast-1.bedrock-runtime"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  subnet_ids          = module.vpc.private_subnets
  private_dns_enabled = true
}

# IAM Policy for ECS to invoke Bedrock models
resource "aws_iam_policy" "ecs_bedrock_policy" {
  name        = "epiq-ecs-bedrock-policy"
  description = "IM8: Least-privilege Bedrock access for ECS GenAI Copilot"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BedrockModelInvocation"
        Effect = "Allow"
        Action = [
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        # IM8: Scoped to specific Claude model only
        Resource = [
          "arn:aws:bedrock:ap-southeast-1::foundation-model/anthropic.claude-3-haiku-20240307-v1:0",
          "arn:aws:bedrock:ap-southeast-1::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0"
        ]
      },
      {
        Sid    = "BedrockListModels"
        Effect = "Allow"
        Action = [
          "bedrock:ListFoundationModels",
          "bedrock:GetFoundationModel"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_bedrock_attach" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = aws_iam_policy.ecs_bedrock_policy.arn
}

# Output for app configuration
output "bedrock_endpoint" {
  value       = "https://bedrock-runtime.ap-southeast-1.amazonaws.com"
  description = "Bedrock runtime endpoint - traffic routes via VPC endpoint"
}

output "bedrock_model_id" {
  value       = "anthropic.claude-3-haiku-20240307-v1:0"
  description = "Default Bedrock model for GenAI Copilot"
}