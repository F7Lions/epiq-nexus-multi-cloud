module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "epiq-discovery-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["ap-southeast-1a", "ap-southeast-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  # FinOps Strategy: Disable NAT Gateway for now to save $1.00/day
  # We will use VPC Endpoints in the next step for ECR/S3 access.
  enable_nat_gateway = false 
  enable_vpn_gateway = false

  manage_default_security_group = true
  default_security_group_ingress = [] # IM8: Deny all by default
  default_security_group_egress  = []
}