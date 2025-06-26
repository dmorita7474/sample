#------------------------------------------------------------------------------
# IAM Roles
#------------------------------------------------------------------------------

# ECSタスク実行ロール (イメージのプル、CloudWatchへのログ書き込みなど)
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# アプリケーションタスクロール (アプリケーションが他のAWSサービスを呼び出すため)
resource "aws_iam_role" "app_task_role" {
  name = "app-task-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# 将来的にX-Rayなどを利用するために、基本的な権限を付与しておきます
resource "aws_iam_role_policy_attachment" "app_task_role_xray" {
  role       = aws_iam_role.app_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

resource "aws_iam_role_policy_attachment" "app_task_role_cloudwatch" {
  role       = aws_iam_role.app_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# IAM policy to allow reading the DB credentials from Secrets Manager
resource "aws_iam_policy" "secrets_manager_access" {
  name        = "secrets-manager-access-policy"
  description = "Allow reading DB credentials from Secrets Manager"

  policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action   = "secretsmanager:GetSecretValue",
        Effect   = "Allow",
        Resource = aws_secretsmanager_secret.aurora_master_password.arn
      }
    ]
  })
}

# Attach the Secrets Manager policy to the app task role
resource "aws_iam_role_policy_attachment" "app_task_role_secrets_manager" {
  role       = aws_iam_role.app_task_role.name
  policy_arn = aws_iam_policy.secrets_manager_access.policy_arn
}


#------------------------------------------------------------------------------
# Security Groups
#------------------------------------------------------------------------------

resource "aws_security_group" "nextjs_sg" {
  name        = "nextjs-app-sg"
  description = "Allow traffic for Next.js app from load balancer"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [module.alb.security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "fastapi_sg" {
  name        = "fastapi-app-sg"
  description = "Allow traffic for FastAPI app"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block] # Allow traffic only from within the VPC
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#------------------------------------------------------------------------------
# ALB for Next.js using Terraform Registry Module
#------------------------------------------------------------------------------

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "9.7.0"

  name = "nextjs-alb"

  load_balancer_type = "application"

  vpc_id  = module.vpc.vpc_id
  subnets = module.vpc.public_subnets

  # Listener for HTTP on port 80
  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"
      forward = {
        target_group_key = "nextjs-tg"
      }
    }
  }

  # Target group for Next.js app on port 3000
  target_groups = {
    "nextjs-tg" = {
      name_prefix      = "nextjs-"
      backend_protocol = "HTTP"
      backend_port     = 3000
      target_type      = "ip"
      health_check = {
        path = "/"
      }
    }
  }
}


#------------------------------------------------------------------------------
# ECS Task Definitions & Services
#------------------------------------------------------------------------------

# Next.js Application
resource "aws_ecs_task_definition" "nextjs" {
  family                   = "nextjs-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512" # Increased for sidecar
  memory                   = "1024" # Increased for sidecar
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.app_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "nextjs-app"
      image     = "${aws_ecr_repository.nextjs.repository_url}:latest"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/nextjs-app",
          "awslogs-region"        = "ap-northeast-1",
          "awslogs-stream-prefix" = "ecs"
        }
      }
      environment = [
        { 
          name = "OTEL_EXPORTER_OTLP_ENDPOINT", 
          value = "http://localhost:4317" 
        }
      ]
      dependsOn = [
        {
          containerName = "aws-otel-collector",
          condition     = "HEALTHY"
        }
      ]
    },
    {
      name      = "aws-otel-collector"
      image     = "public.ecr.aws/aws-observability/aws-otel-collector:latest"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 4317 # gRPC
        },
        {
          containerPort = 4318 # HTTP
        }
      ]
      command = [
        "--config=/etc/ecs/ecs-default-config.yaml"
      ]
      secrets = [
        {
          name      = "AOT_CONFIG_CONTENT",
          valueFrom = aws_ssm_parameter.adot_config.arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.adot_collector_logs.name,
          "awslogs-region"        = "ap-northeast-1",
          "awslogs-stream-prefix" = "ecs"
        }
      }
      healthCheck = {
        command     = ["/healthcheck"]
        interval    = 10
        timeout     = 5
        retries     = 3
        startPeriod = 15
      }
    }
  ])
}

resource "aws_ecs_service" "nextjs" {
  name            = "nextjs-service"
  cluster         = module.ecs.cluster_id
  task_definition = aws_ecs_task_definition.nextjs.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = module.vpc.private_subnets
    security_groups = [aws_security_group.nextjs_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = module.alb.target_groups["nextjs-tg"].arn
    container_name   = "nextjs-app"
    container_port   = 3000
  }

  # The service needs to wait for the load balancer to be ready.
  depends_on = [module.alb]
}

# FastAPI Application
resource "aws_ecs_task_definition" "fastapi" {
  family                   = "fastapi-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512" # Increased for sidecar
  memory                   = "1024" # Increased for sidecar
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.app_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "fastapi-app"
      image     = "${aws_ecr_repository.fastapi.repository_url}:latest"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 8000
          hostPort      = 8000
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/fastapi-app",
          "awslogs-region"        = "ap-northeast-1",
          "awslogs-stream-prefix" = "ecs"
        }
      }
      environment = [
        { 
          name = "OTEL_EXPORTER_OTLP_ENDPOINT", 
          value = "http://localhost:4317" 
        },
        { 
          name = "DB_HOST", 
          value = aws_rds_cluster.aurora.endpoint 
        },
        { 
          name = "DB_NAME", 
          value = aws_rds_cluster.aurora.database_name 
        },
        { 
          name = "DB_CREDENTIALS_SECRET_ARN", 
          value = aws_secretsmanager_secret.aurora_master_password.arn 
        }
      ]
      dependsOn = [
        {
          containerName = "aws-otel-collector",
          condition     = "HEALTHY"
        }
      ]
    },
    {
      name      = "aws-otel-collector"
      image     = "public.ecr.aws/aws-observability/aws-otel-collector:latest"
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 4317 # gRPC
        },
        {
          containerPort = 4318 # HTTP
        }
      ]
      command = [
        "--config=/etc/ecs/ecs-default-config.yaml"
      ]
      secrets = [
        {
          name      = "AOT_CONFIG_CONTENT",
          valueFrom = aws_ssm_parameter.adot_config.arn
        }
      ]
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.adot_collector_logs.name,
          "awslogs-region"        = "ap-northeast-1",
          "awslogs-stream-prefix" = "ecs"
        }
      }
      healthCheck = {
        command     = ["/healthcheck"]
        interval    = 10
        timeout     = 5
        retries     = 3
        startPeriod = 15
      }
    }
  ])
}

resource "aws_ecs_service" "fastapi" {
  name            = "fastapi-service"
  cluster         = module.ecs.cluster_id
  task_definition = aws_ecs_task_definition.fastapi.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = module.vpc.private_subnets
    security_groups = [aws_security_group.fastapi_sg.id]
    assign_public_ip = false
  }

  service_registries {
    registry_arn = aws_service_discovery_service.fastapi.arn
  }
}