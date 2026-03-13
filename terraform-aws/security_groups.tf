resource "aws_security_group" "vpc_endpoints" {
  name        = "epiq-vpce-sg"
  description = "Allow private traffic to AWS services"
  vpc_id      = module.vpc.vpc_id
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
}
resource "aws_security_group" "ecs_tasks" {
  name        = "epiq-ecs-sg"
  vpc_id      = module.vpc.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
