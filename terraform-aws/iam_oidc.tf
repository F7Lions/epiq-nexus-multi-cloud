# 1. GitHub OIDC Provider
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1", "1c58a3a8518e8759bf075b76b750d4f2df264fcd"]
}

# 2. GitHub Actions IAM Role
resource "aws_iam_role" "github_actions_role" {
  name = "epiq-github-oidc-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:F7Lions/epiq-nexus-multi-cloud:*"
          }
        }
      }
    ]
  })
}

# 3. IM8: Least-Privilege Policy - Only what the pipeline actually needs
resource "aws_iam_policy" "github_actions_policy" {
  name        = "epiq-github-actions-policy"
  description = "IM8: Least-privilege policy for GitHub Actions OIDC pipeline"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRAuthentication"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      },
      {
        Sid    = "ECRImageOperations"
        Effect = "Allow"
        Action = [
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:GetDownloadUrlForLayer",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:BatchDeleteImage",
          "ecr:DescribeImages"
        ]
        Resource = "arn:aws:ecr:ap-southeast-1:${data.aws_caller_identity.current.account_id}:repository/epiq-discovery-engine"
      },
      {
        Sid    = "ECSDeployment"
        Effect = "Allow"
        Action = [
          "ecs:UpdateService",
          "ecs:DescribeServices",
          "ecs:DescribeClusters"
        ]
        Resource = [
          "arn:aws:ecs:ap-southeast-1:${data.aws_caller_identity.current.account_id}:cluster/epiq-discovery-cluster",
          "arn:aws:ecs:ap-southeast-1:${data.aws_caller_identity.current.account_id}:service/epiq-discovery-cluster/epiq-discovery-service"
        ]
      }
    ]
  })
}

# 4. Attach least-privilege policy instead of AdministratorAccess
resource "aws_iam_role_policy_attachment" "github_actions_attach" {
  role       = aws_iam_role.github_actions_role.name
  policy_arn = aws_iam_policy.github_actions_policy.arn
}

output "github_actions_role_arn" {
  value = aws_iam_role.github_actions_role.arn
}