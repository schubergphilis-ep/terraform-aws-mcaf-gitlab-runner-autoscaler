data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  updated_runners = merge(var.gitlab_runner_config, {
    runners = [merge(var.gitlab_runner_config.runners, {
      token = var.gitlab_runner_token
      autoscaler = merge(var.gitlab_runner_config.runners.autoscaler, {
        connector_config = merge(var.gitlab_runner_config.runners.autoscaler.connector_config, {
          use_static_credentials = false
        })
        plugin_config = merge(var.gitlab_runner_config.runners.autoscaler.plugin_config, {
          name = "${var.gitlab_runner_config.runners.name}-instance-asg"
        })
      })
    })]
  })
}

resource "aws_secretsmanager_secret" "config" {
  #checkov:skip=CKV2_AWS_57:GitLab Runner config is rotated manually via CONFIG_HASH environment variable trigger, not via automatic rotation

  name_prefix = var.gitlab_runner_config.runners.name
  kms_key_id  = var.kms_key_id

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "config" {
  secret_id     = aws_secretsmanager_secret.config.id
  secret_string = jsonencode(local.updated_runners)
}

data "aws_iam_policy_document" "task_execution_role" {
  #checkov:skip=CKV_AWS_107:secretsmanager:GetSecretValue is required for runner to access configuration
  #checkov:skip=CKV_AWS_356:EC2 and AutoScaling describe actions require wildcard resources to discover and manage dynamic infrastructure
  #checkov:skip=CKV_AWS_111:ec2-instance-connect targets dynamic instance IDs; scoped to account/region ARN and restricted via ec2:ResourceTag/Name condition

  statement {
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = [
      aws_secretsmanager_secret.config.arn
    ]
  }

  statement {
    actions   = ["ec2-instance-connect:SendSSHPublicKey"]
    resources = ["arn:aws:ec2:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:instance/*"]

    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/Name"
      values   = ["${var.gitlab_runner_config.runners.name}-instance"]
    }
  }

  statement {
    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup"
    ]
    resources = [
      "arn:aws:autoscaling:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:autoScalingGroup:*:autoScalingGroupName/${var.gitlab_runner_config.runners.name}-instance-asg"
    ]
  }

  statement {
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "ec2:DescribeInstances",
      "ec2:DescribeSpotInstanceRequests"
    ]
    resources = ["*"]
  }

  dynamic "statement" {
    for_each = var.kms_key_id != null ? [var.kms_key_id] : []
    content {
      actions = [
        "kms:Decrypt",
        "kms:DescribeKey"
      ]
      resources = [statement.value]
    }
  }
}

module "runner_manager" {
  #checkov:skip=CKV2_AWS_28:We dont use the lb
  #checkov:skip=CKV_AWS_91:We are not using the LB, so no access logs

  source  = "schubergphilis/mcaf-fargate/aws"
  version = "~> 2.2.0"

  name                     = "${var.gitlab_runner_config.runners.name}-manager"
  architecture             = "arm64" # Manager always runs on ARM64 for cost optimization
  command                  = var.gitlab_runner_command
  ecs_subnet_ids           = var.vpc_subnet_ids
  image                    = var.gitlab_runner_image
  kms_key_id               = var.kms_key_id
  public_ip                = false
  readonly_root_filesystem = false
  role_policy              = data.aws_iam_policy_document.task_execution_role.json
  vpc_id                   = var.vpc_id
  tags                     = var.tags

  environment = merge(
    {
      CONFIG_HASH               = md5(jsonencode(local.updated_runners))
      GITLAB_CONFIG_SECRET_NAME = aws_secretsmanager_secret.config.name
    },
    length(var.docker_credential_helpers) > 0 ? {
      DOCKER_CREDENTIAL_HELPERS = jsonencode(var.docker_credential_helpers)
    } : {}
  )
}
