# modules/elasticache/main.tf

#------------------------------------------------------------------------------
# Security Group
#------------------------------------------------------------------------------
resource "aws_security_group" "this" {
  name        = "${var.name}-redis-sg"
  description = "Security group for ElastiCache Redis"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name}-redis-sg"
  })
}

resource "aws_security_group_rule" "ingress_eks" {
  count = var.eks_security_group_id != "" ? 1 : 0

  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = var.eks_security_group_id
  security_group_id        = aws_security_group.this.id
  description              = "Allow from EKS"
}

resource "aws_security_group_rule" "ingress_ecs" {
  count = var.ecs_security_group_id != "" ? 1 : 0

  type                     = "ingress"
  from_port                = 6379
  to_port                  = 6379
  protocol                 = "tcp"
  source_security_group_id = var.ecs_security_group_id
  security_group_id        = aws_security_group.this.id
  description              = "Allow from ECS"
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
# Parameter Group
#------------------------------------------------------------------------------
resource "aws_elasticache_parameter_group" "this" {
  name   = "${var.name}-redis-params"
  family = "redis7"

  # 티켓팅 대기열 최적화
  parameter {
    name  = "maxmemory-policy"
    value = "volatile-lru"
  }

  parameter {
    name  = "timeout"
    value = "300"
  }

  tags = var.tags
}

#------------------------------------------------------------------------------
# ElastiCache Replication Group (Cluster Mode)
#------------------------------------------------------------------------------
resource "aws_elasticache_replication_group" "this" {
  replication_group_id = var.name
  description          = "Redis cluster for ${var.name}"

  engine               = "redis"
  engine_version       = var.engine_version
  node_type            = var.node_type
  port                 = 6379
  parameter_group_name = aws_elasticache_parameter_group.this.name

  # Cluster mode 설정
  num_node_groups         = var.num_shards
  replicas_per_node_group = var.replicas_per_shard

  subnet_group_name  = var.subnet_group_name
  security_group_ids = [aws_security_group.this.id]

  at_rest_encryption_enabled = true
  transit_encryption_enabled = false # 성능 우선

  automatic_failover_enabled = var.num_shards > 1 || var.replicas_per_shard > 0
  multi_az_enabled           = var.replicas_per_shard > 0

  # 백업 설정 (비용 절감을 위해 최소화)
  snapshot_retention_limit = var.environment == "prod" ? 1 : 0
  snapshot_window          = "05:00-06:00"
  maintenance_window       = "Mon:06:00-Mon:07:00"

  # 알림
  notification_topic_arn = var.sns_topic_arn

  tags = merge(var.tags, {
    Name = var.name
  })
}
