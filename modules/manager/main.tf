data "aws_region" "current" {}

locals {
  updated_runners = merge(var.gitlab_runner_config, {
    runners = [merge(var.gitlab_runner_config.runners, {
      token = var.gitlab_runner_token
      autoscaler = merge(var.gitlab_runner_config.runners.autoscaler, {
        plugin_config = merge(var.gitlab_runner_config.runners.autoscaler.plugin_config, {
          name = "${var.gitlab_runner_config.runners.name}-instance-asg"
        })
      })
    })]
  })
}

data "aws_iam_policy_document" "task_execution_role" {
  #checkov:skip=CKV_AWS_107:secretsmanager:GetSecretValue is required for runner to access configuration and SSH keys
  #checkov:skip=CKV_AWS_356:EC2 and AutoScaling describe actions require wildcard resources to discover and manage dynamic infrastructure
  #checkov:skip=CKV_AWS_111:ec2-instance-connect requires wildcard resource as instance IDs are dynamic; access is restricted via ec2:ResourceTag/Name condition

  statement {
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    resources = [
      aws_secretsmanager_secret.config.arn,
      aws_secretsmanager_secret.ssh_key.arn
    ]
  }

  #tfsec:ignore:aws-iam-no-policy-wildcards ec2-instance-connect requires wildcard resource as instance IDs are dynamic; access is restricted via ec2:ResourceTag/Name condition
  statement {
    actions   = ["ec2-instance-connect:SendSSHPublicKey"]
    resources = ["*"] #tfsec:ignore:aws-iam-no-policy-wildcards

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
      "arn:aws:autoscaling:*:*:autoScalingGroup:*:autoScalingGroupName/${var.gitlab_runner_config.runners.name}-instance-asg"
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

resource "aws_secretsmanager_secret" "ssh_key" {
  #checkov:skip=CKV2_AWS_57:SSH private keys cannot use automatic rotation as it would break instance connectivity; keys are rotated through infrastructure redeployment

  name_prefix = var.gitlab_runner_config.runners.name
  kms_key_id  = var.kms_key_id

  tags = var.tags
}
resource "aws_secretsmanager_secret_version" "ssh_key" {
  secret_id     = aws_secretsmanager_secret.ssh_key.id
  secret_string = trimspace(tls_private_key.default.private_key_openssh)
}

resource "tls_private_key" "default" {
  algorithm = "ED25519"
}

module "runner_manager" {
  #checkov:skip=CKV2_AWS_28:We dont use the lb
  #checkov:skip=CKV_AWS_91:We are not using the LB, so no access logs

  source  = "schubergphilis/mcaf-fargate/aws"
  version = "2.2.0"

  name           = "${var.gitlab_runner_config.runners.name}-manager"
  architecture   = "arm64" # Manager always runs on ARM64 for cost optimization
  command        = var.gitlab_runner_command
  ecs_subnet_ids = var.vpc_subnet_ids
  environment = merge(
    {
      CONFIG_HASH               = md5(jsonencode(local.updated_runners))
      GITLAB_CONFIG_SECRET_NAME = aws_secretsmanager_secret.config.name
      SSH_KEY_SECRET_NAME       = aws_secretsmanager_secret.ssh_key.name
    },
    length(var.docker_credential_helpers) > 0 ? {
      DOCKER_CREDENTIAL_HELPERS = jsonencode(var.docker_credential_helpers)
    } : {}
  )
  image                    = var.gitlab_runner_image
  public_ip                = false
  readonly_root_filesystem = false
  role_policy              = data.aws_iam_policy_document.task_execution_role.json
  vpc_id                   = var.vpc_id
  tags                     = var.tags
}
