# 1. ALB Security Group
resource "aws_security_group" "alb_sg" {
  name        = "epiq-alb-sg"
  description = "IM8: ALB security group - HTTP ingress only"
  vpc_id      = module.vpc.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  ingress {
    description = "IM8: HTTP from Internet - redirects to HTTPS"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "IM8: HTTPS from Internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "IM8: Allow outbound to ECS only"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
}
# 2. ALB Access Logging Bucket
resource "aws_s3_bucket" "alb_logs" {
  bucket        = "epiq-alb-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket                  = aws_s3_bucket.alb_logs.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::114774131450:root" }
      Action    = "s3:PutObject"
      Resource  = "${aws_s3_bucket.alb_logs.arn}/alb-logs/AWSLogs/${data.aws_caller_identity.current.account_id}/*"
    }]
  })
}

# 3. Application Load Balancer
resource "aws_lb" "epiq_alb" {
  name               = "epiq-discovery-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = module.vpc.public_subnets
  
  # CKV_AWS_131: IM8 - Drop invalid HTTP headers
  drop_invalid_header_fields = true

  # CKV_AWS_150: IM8 - Prevent accidental deletion
  enable_deletion_protection = false # Keep false for showcase FinOps teardown

  # CKV_AWS_91: IM8 - Access logging for audit trail
  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = "alb-logs"
    enabled = true
  }
}

# 4. Target Group with Health Check
resource "aws_lb_target_group" "epiq_tg" {
  name        = "epiq-discovery-tg-v6"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  # CKV_AWS_261: IM8 - Health check required
  health_check {
    enabled             = true
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# 5. HTTP Listener - Redirects to HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.epiq_alb.arn
  port              = "80"
  protocol          = "HTTP"

  # IM8: Redirect all HTTP to HTTPS (301 Permanent)
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# 6. HTTPS Listener
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.epiq_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.epiq_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.epiq_tg.arn
  }
}

# 7. Self-signed ACM Certificate for showcase
resource "aws_acm_certificate" "epiq_cert" {
  private_key       = tls_private_key.epiq_key.private_key_pem
  certificate_body  = tls_self_signed_cert.epiq_cert.cert_pem

  lifecycle {
    create_before_destroy = true
  }
}

resource "tls_private_key" "epiq_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "epiq_cert" {
  private_key_pem = tls_private_key.epiq_key.private_key_pem

  subject {
    common_name  = "epiq-discovery.internal"
    organization = "Epiq Showcase"
  }

  validity_period_hours = 8760 # 1 year
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# 8. ECS Cluster with Container Insights
resource "aws_ecs_cluster" "epiq_cluster" {
  name = "epiq-discovery-cluster"

  # CKV_AWS_65: IM8 - Container insights for monitoring
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# 9. ECS Security Group
resource "aws_security_group" "ecs_sg" {
  name        = "epiq-ecs-sg-v4"
  description = "IM8: ECS tasks - ALB ingress only, VPC egress only"
  vpc_id      = module.vpc.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  ingress {
    description     = "IM8: HTTPS traffic from ALB only"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    description = "IM8: Allow outbound to VPC only for VPC Endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }
}

# 10. ECS Task Definition
resource "aws_ecs_task_definition" "epiq_task" {
  family                   = "epiq-discovery-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([{
    name      = "epiq-discovery-container"
    image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.ap-southeast-1.amazonaws.com/epiq-discovery-engine:latest"
    essential = true
    portMappings = [{
      containerPort = 8080
      hostPort      = 8080
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/epiq-discovery"
        "awslogs-region"        = "ap-southeast-1"
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

# 11. ECS Service
resource "aws_ecs_service" "epiq_service" {
  name            = "epiq-discovery-service"
  cluster         = aws_ecs_cluster.epiq_cluster.id
  task_definition = aws_ecs_task_definition.epiq_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.epiq_tg.arn
    container_name   = "epiq-discovery-container"
    container_port   = 8080
  }
}

# 12. Supporting Resources
data "aws_caller_identity" "current" {}

resource "aws_iam_role" "ecs_execution_role" {
  name = "epiq_ecs_execution_role_v2"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/epiq-discovery"
  retention_in_days = 30
}