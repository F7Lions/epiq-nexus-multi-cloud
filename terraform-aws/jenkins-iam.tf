# IM8: Dedicated least-privilege IAM user for local Jenkins auditor
# Note: OIDC not feasible for local Jenkins - using scoped IAM user instead
resource "aws_iam_user" "jenkins_auditor" {
  name = "epiq-jenkins-auditor"
  path = "/service-accounts/"

  tags = {
    Purpose = "Local Jenkins IM8 Compliance Gate"
    Note    = "Rotate keys every 90 days per IM8 requirement"
  }
}

resource "aws_iam_policy" "jenkins_auditor_policy" {
  name        = "epiq-jenkins-auditor-policy"
  description = "IM8: Least-privilege policy for local Jenkins compliance gate"

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
        Sid    = "ECRReadOnly"
        Effect = "Allow"
        Action = [
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:DescribeImages",
          "ecr:ListImages"
        ]
        Resource = "arn:aws:ecr:ap-southeast-1:${data.aws_caller_identity.current.account_id}:repository/epiq-discovery-engine"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "jenkins_auditor_attach" {
  user       = aws_iam_user.jenkins_auditor.name
  policy_arn = aws_iam_policy.jenkins_auditor_policy.arn
}

# Generate access keys for Jenkins
resource "aws_iam_access_key" "jenkins_auditor" {
  user = aws_iam_user.jenkins_auditor.name
}

# Output the keys - these go into Jenkins Credentials Manager
output "jenkins_auditor_access_key_id" {
  value     = aws_iam_access_key.jenkins_auditor.id
  sensitive = false
}

output "jenkins_auditor_secret_key" {
  value     = aws_iam_access_key.jenkins_auditor.secret
  sensitive = true
}