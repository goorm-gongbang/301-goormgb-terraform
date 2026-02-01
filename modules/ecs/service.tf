# modules/ecs/service.tf

#------------------------------------------------------------------------------
# Task Definition - AI Control Plane (Service A)
#------------------------------------------------------------------------------
resource "aws_ecs_task_definition" "ai_control" {
  family                   = "${var.cluster_name}-ai-control"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name  = "ai-control"
      image = var.container_image
      portMappings = [
        {
          containerPort = var.container_port
          hostPort      = var.container_port
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "ENVIRONMENT"
          value = var.environment
        },
        {
          name  = "PORT"
          value = tostring(var.container_port)
        }
      ]
      secrets = [
        for secret in var.container_secrets : {
          name      = secret.name
          valueFrom = secret.value_from
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ai-control"
        }
      }
      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:${var.container_port}/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])

  tags = var.tags
}

data "aws_region" "current" {}

#------------------------------------------------------------------------------
# ECS Service - AI Control Plane
#------------------------------------------------------------------------------
resource "aws_ecs_service" "ai_control" {
  name            = "ai-control-plane"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.ai_control.arn

  # prod: 2개 (HA), dev: 1개
  desired_count = var.environment == "prod" ? 2 : 1

  # Fargate Spot 사용
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
    base              = var.environment == "prod" ? 2 : 1
  }

  # prod는 최소 50% 유지, dev는 다운타임 허용
  deployment_configuration {
    maximum_percent         = 200
    minimum_healthy_percent = var.environment == "prod" ? 50 : 0
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.tasks.id]
    assign_public_ip = false
  }

  # ALB 연결 (선택적)
  dynamic "load_balancer" {
    for_each = var.target_group_arn != "" ? [1] : []
    content {
      target_group_arn = var.target_group_arn
      container_name   = "ai-control"
      container_port   = var.container_port
    }
  }

  # Task가 종료되어도 서비스 유지 (Spot 대응)
  enable_execute_command = true

  tags = var.tags

  lifecycle {
    ignore_changes = [task_definition]
  }
}

#------------------------------------------------------------------------------
# Task Definition - Test Automation (Service B) - Run Task용
#------------------------------------------------------------------------------
resource "aws_ecs_task_definition" "ai_test" {
  family                   = "${var.cluster_name}-ai-test"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name  = "ai-test"
      image = var.test_container_image != "" ? var.test_container_image : var.container_image
      environment = [
        {
          name  = "ENVIRONMENT"
          value = var.environment
        },
        {
          name  = "TEST_MODE"
          value = "true"
        }
      ]
      secrets = [
        for secret in var.container_secrets : {
          name      = secret.name
          valueFrom = secret.value_from
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.this.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ai-test"
        }
      }
    }
  ])

  tags = var.tags
}
