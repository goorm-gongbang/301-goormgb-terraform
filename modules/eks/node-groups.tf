# modules/eks/node-groups.tf

#------------------------------------------------------------------------------
# Initial Node Group (Karpenter 부트스트랩용 최소 노드)
# Karpenter가 실행되려면 최소 노드가 필요함
#------------------------------------------------------------------------------
resource "aws_eks_node_group" "initial" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-initial"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids

  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }

  # Spot 인스턴스 사용
  capacity_type = "SPOT"

  instance_types = ["m5.large", "m5a.large", "m6i.large"]

  labels = {
    "node-type" = "initial"
  }

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-initial-node"
  })

  depends_on = [
    aws_iam_role_policy_attachment.node_policies
  ]
}

#------------------------------------------------------------------------------
# Launch Template for Karpenter Nodes
#------------------------------------------------------------------------------
resource "aws_launch_template" "karpenter" {
  name = "${var.cluster_name}-karpenter-lt"

  vpc_security_group_ids = [aws_security_group.node.id]

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name                                        = "${var.cluster_name}-karpenter-node"
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    })
  }

  tags = var.tags
}
