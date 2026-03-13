# 1. The Secure Container Registry
resource "aws_ecr_repository" "epiq_engine" {
  name                 = "epiq-discovery-engine"
  image_tag_mutability = "IMMUTABLE" # IM8: No overwriting allowed
  force_delete         = true        # FinOps: Allows us to easily terraform destroy

  image_scanning_configuration {
    scan_on_push = true # IM8: Automated vulnerability scanning
  }
}

# 2. FinOps Lifecycle Policy (Keep only the latest 3 images)
resource "aws_ecr_lifecycle_policy" "epiq_cleanup" {
  repository = aws_ecr_repository.epiq_engine.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only the last 3 untagged/dev images to save costs"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 3
      }
      action = {
        type = "expire"
      }
    }]
  })
}

output "ecr_repository_url" {
  value = aws_ecr_repository.epiq_engine.repository_url
}