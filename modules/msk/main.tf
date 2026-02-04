# modules/msk/main.tf
# Amazon MSK (Managed Streaming for Apache Kafka) - Serverless

#------------------------------------------------------------------------------
# Security Group
#------------------------------------------------------------------------------
resource "aws_security_group" "this" {
  name        = "${var.name}-msk-sg"
  description = "Security group for MSK Kafka cluster"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name}-msk-sg"
  })
}

resource "aws_security_group_rule" "ingress_eks" {
  count = var.eks_security_group_id != "" ? 1 : 0

  type                     = "ingress"
  from_port                = 9098
  to_port                  = 9098
  protocol                 = "tcp"
  source_security_group_id = var.eks_security_group_id
  security_group_id        = aws_security_group.this.id
  description              = "Allow Kafka IAM auth from EKS"
}

resource "aws_security_group_rule" "ingress_ecs" {
  count = var.ecs_security_group_id != "" ? 1 : 0

  type                     = "ingress"
  from_port                = 9098
  to_port                  = 9098
  protocol                 = "tcp"
  source_security_group_id = var.ecs_security_group_id
  security_group_id        = aws_security_group.this.id
  description              = "Allow Kafka IAM auth from ECS"
}

resource "aws_security_group_rule" "egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.this.id
}

#------------------------------------------------------------------------------
# MSK Serverless Cluster (비용 최적화)
# - 사용량 기반 과금 (티켓 오픈 시에만 비용 발생)
# - 자동 스케일링 (관리 부담 없음)
#------------------------------------------------------------------------------
resource "aws_msk_serverless_cluster" "this" {
  cluster_name = var.name

  vpc_config {
    subnet_ids         = var.private_subnet_ids
    security_group_ids = [aws_security_group.this.id]
  }

  client_authentication {
    sasl {
      iam {
        enabled = true
      }
    }
  }

  tags = merge(var.tags, {
    Name = var.name
  })
}

#------------------------------------------------------------------------------
# CloudWatch Log Group (선택적)
#------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "this" {
  count = var.enable_logging ? 1 : 0

  name              = "/aws/msk/${var.name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}
