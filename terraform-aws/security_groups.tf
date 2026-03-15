# Security Group for VPC Endpoints (ECR API, ECR DKR, S3)
# IM8: Only allows HTTPS traffic from within the VPC
resource "aws_security_group" "vpc_endpoints" {
  name        = "epiq-vpce-sg"
  description = "Allow private HTTPS traffic to AWS service endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "IM8: HTTPS from VPC only"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    description = "Allow outbound to AWS services"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}