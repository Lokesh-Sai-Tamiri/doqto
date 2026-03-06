# ─────────────────────────────────────────────────────────────────
# ECR — Docker image repository
# ─────────────────────────────────────────────────────────────────
resource "aws_ecr_repository" "app" {
  name                 = "${var.project_name}-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true # HIPAA: detect known CVEs in images
  }

  encryption_configuration {
    encryption_type = "AES256" # Images encrypted at rest
  }

  tags = { Name = "${var.project_name}-api" }
}

resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep only 5 most recent images to limit storage cost"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 5
      }
      action = { type = "expire" }
    }]
  })
}

# ─────────────────────────────────────────────────────────────────
# ECS Cluster
# ─────────────────────────────────────────────────────────────────
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled" # CloudWatch Container Insights for monitoring
  }

  tags = { Name = "${var.project_name}-cluster" }
}

# ─────────────────────────────────────────────────────────────────
# CloudWatch Log Group — app logs (HIPAA: audit trail)
# ─────────────────────────────────────────────────────────────────
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.project_name}"
  retention_in_days = 365 # 1 year; bump to 2555 (7yr) for strictest HIPAA

  tags = {
    Name       = "${var.project_name}-app-logs"
    HIPAAScope = "true"
  }
}

# ─────────────────────────────────────────────────────────────────
# IAM — Task Execution Role
# Used by the ECS agent (not your app) to:
#   - Pull image from ECR
#   - Push logs to CloudWatch
#   - Fetch secrets from Secrets Manager at task startup
# ─────────────────────────────────────────────────────────────────
resource "aws_iam_role" "task_execution" {
  name = "${var.project_name}-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "${var.project_name}-ecs-execution-role" }
}

resource "aws_iam_role_policy_attachment" "execution_managed" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "execution_secrets" {
  name = "${var.project_name}-execution-read-secrets"
  role = aws_iam_role.task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource = var.secret_arn
    }]
  })
}

# ─────────────────────────────────────────────────────────────────
# IAM — Task Role
# Used by your running application code to access AWS services.
# Grants S3 access for the three app buckets — NO access keys needed.
# boto3 picks up these credentials automatically via the metadata endpoint.
# ─────────────────────────────────────────────────────────────────
resource "aws_iam_role" "task" {
  name = "${var.project_name}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "${var.project_name}-ecs-task-role" }
}

resource "aws_iam_role_policy" "task_s3" {
  name = "${var.project_name}-task-s3-access"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ObjectAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:GetObjectAcl",
          "s3:PutObjectAcl",
        ]
        Resource = [for b in var.s3_bucket_names : "arn:aws:s3:::${b}/*"]
      },
      {
        Sid    = "BucketAccess"
        Effect = "Allow"
        Action = ["s3:ListBucket", "s3:GetBucketLocation"]
        Resource = [for b in var.s3_bucket_names : "arn:aws:s3:::${b}"]
      }
    ]
  })
}

# ─────────────────────────────────────────────────────────────────
# ECS Task Definition
# ─────────────────────────────────────────────────────────────────
resource "aws_ecs_task_definition" "app" {
  family                   = "${var.project_name}-api"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name  = "${var.project_name}-api"
      image = var.container_image

      portMappings = [{ containerPort = 8000, protocol = "tcp" }]

      # Non-sensitive env vars passed as plaintext
      environment = [
        for k, v in var.app_env_vars : { name = k, value = v }
      ]

      # Sensitive vars fetched from Secrets Manager at task startup.
      # Format: "<secret_arn>:<json_key>::"  (region/version qualifiers omitted = latest)
      secrets = [
        for key in var.secret_keys : {
          name      = key
          valueFrom = "${var.secret_arn}:${key}::"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "api"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "python -c \"import urllib.request; urllib.request.urlopen('http://localhost:8000/health')\" || exit 1"]
        interval    = 30
        timeout     = 10
        retries     = 3
        startPeriod = 60
      }

      essential = true
    }
  ])

  tags = { Name = "${var.project_name}-api-taskdef" }
}

# ─────────────────────────────────────────────────────────────────
# ECS Service — rolling update ensures zero downtime
#
# minimum_healthy_percent = 100 → old task stays until new one is healthy
# maximum_percent         = 200 → temporarily runs 2 tasks during deploy
# circuit_breaker + rollback → auto-reverts if new task fails health check
# ─────────────────────────────────────────────────────────────────
resource "aws_ecs_service" "app" {
  name            = "${var.project_name}-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true # auto-rollback on failed deployment
  }

  network_configuration {
    subnets          = var.public_subnet_ids
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = true # no NAT gateway needed; SG blocks all non-ALB inbound
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = "${var.project_name}-api"
    container_port   = 8000
  }

  lifecycle {
    # Ignore task_definition so CI/CD image updates (via deploy.sh) don't
    # conflict with Terraform state. Terraform manages infrastructure;
    # deploy.sh manages image versions.
    ignore_changes = [task_definition]
  }

  depends_on = [
    aws_iam_role_policy_attachment.execution_managed,
    aws_iam_role_policy.execution_secrets,
  ]

  tags = { Name = "${var.project_name}-api-service" }
}
