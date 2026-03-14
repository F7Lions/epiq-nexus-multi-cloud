# 1. Application Load Balancer (ALB)
resource "aws_security_group" "alb_sg" {
  name        = "epiq-alb-sg"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP from Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb" "epiq_alb" {
  name               = "epiq-discovery-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = module.vpc.public_subnets
}

resource "aws_lb_target_group" "epiq_tg" {
  name        = "epiq-discovery-tg-v5" # Incrementing version to be safe
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.epiq_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.epiq_tg.arn
  }
}

# 2. ECS Infrastructure
resource "aws_ecs_cluster" "epiq_cluster" {
  name = "epiq-discovery-cluster"
}

resource "aws_security_group" "ecs_sg" {
  name        = "epiq-ecs-sg-v3"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Traffic from ALB"
    from_port       = 8080 # Container port
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 3. Task & Service
resource "aws_ecs_task_definition" "epiq_task" {
  family                   = "epiq-discovery-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([{
    name  = "epiq-discovery-container"
    image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.ap-southeast-1.amazonaws.com/epiq-discovery-engine:latest"
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

resource "aws_ecs_service" "epiq_service" {
  name            = "epiq-discovery-service"
  cluster         = aws_ecs_cluster.epiq_cluster.id
  task_definition = aws_ecs_task_definition.epiq_task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  network_configuration {
    subnets          = module.vpc.public_subnets # Moved to public
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = true # Enabled public IP
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.epiq_tg.arn
    container_name   = "epiq-discovery-container"
    container_port   = 8080
  }
}
# The "Key": Grabs your AWS Account ID dynamically
data "aws_caller_identity" "current" {}

# The "Battery": Gives ECS permission to pull from ECR and send logs to CloudWatch
resource "aws_iam_role" "ecs_execution_role" {
  name = "epiq_ecs_execution_role_v2" # Using v2 to avoid name conflicts
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
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
  retention_in_days = 1
}