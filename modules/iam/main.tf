#iam/main.tf
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.17.0"
    }
  }
}
locals {
  common_policies = [
    "arn:aws:iam::aws:policy/IAMUserChangePassword"
  ]

  group_config = {
    "backend" = [
      "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess",
      "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
    ]
    "frontend" = [
      "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess",
      "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly"
    ]
    "projectmanage" = [
      "arn:aws:iam::aws:policy/AWSBillingReadOnlyAccess"
    ]
    "AI" = [
      "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
    ]
    "security" = [
      "arn:aws:iam::aws:policy/SecurityAudit",
      "arn:aws:iam::aws:policy/AWSWAFConsoleFullAccess",
      "arn:aws:iam::aws:policy/AWSCloudTrail_ReadOnlyAccess"
    ]
  }
  # 이중 반복문 처리용
  group_policy_attachments = flatten([
    for group_name, policies in local.group_config : [
      for policy in concat(policies, local.common_policies) : {
        group  = group_name
        policy = policy
      }
    ]
  ])
}

resource "aws_iam_group" "this" {
  for_each = local.group_config
  name = each.key
  path = "/users/"
}

resource "aws_iam_group_policy_attachment" "this" {
  for_each = {
    for entry in local.group_policy_attachments : "${entry.group}-${entry.policy}" => entry
  }
  group      = aws_iam_group.this[each.value.group].name
  policy_arn = each.value.policy
}