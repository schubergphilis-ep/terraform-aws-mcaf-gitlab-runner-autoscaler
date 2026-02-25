# Query AWS for suitable instance types based on architecture and specs
data "aws_ec2_instance_types" "default" {
  filter {
    name   = "processor-info.supported-architecture"
    values = [var.architecture]
  }

  filter {
    name   = "instance-storage-supported"
    values = ["true"]
  }

  filter {
    name   = "instance-storage-info.nvme-support"
    values = ["required"]
  }

  filter {
    name   = "current-generation"
    values = ["true"]
  }

  filter {
    name   = "bare-metal"
    values = ["false"]
  }

  # Filter by CPU cores (2-8 vCPUs)
  filter {
    name   = "vcpu-info.default-vcpus"
    values = ["2", "4"]
  }

  # Filter by memory (4-16 GiB)
  filter {
    name   = "memory-info.size-in-mib"
    values = ["4096", "8192"]
  }

  # Focus on compute-optimized instances (C family)
  filter {
    name   = "instance-type"
    values = ["c*", "m*"]
  }
}

locals {
  # Use provided instance types or fall back to dynamically discovered ones
  # Sort by name to get a consistent ordering (c8gd, c7gd, etc.)
  discovered_instance_types = sort(data.aws_ec2_instance_types.default.instance_types)
  instance_types            = var.instance_types != null ? var.instance_types : local.discovered_instance_types
}

resource "aws_autoscaling_group" "default" {
  name                  = "${var.gitlab_runner_config.runners.name}-instance-asg"
  capacity_rebalance    = false
  desired_capacity      = 0
  max_size              = var.gitlab_runner_config.runners.autoscaler.max_instances
  min_size              = 0
  protect_from_scale_in = true
  vpc_zone_identifier   = var.vpc_subnet_ids

  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.default.id
        version            = "$Latest"
      }

      dynamic "override" {
        for_each = local.instance_types
        content {
          instance_type = override.value
        }
      }
    }

    instances_distribution {
      on_demand_base_capacity                  = var.on_demand_base_capacity
      on_demand_percentage_above_base_capacity = var.on_demand_percentage_above_base
      spot_allocation_strategy                 = "price-capacity-optimized" # Best practice
      spot_instance_pools                      = 0                          # Use all pools with price-capacity-optimized
    }
  }

  dynamic "tag" {
    for_each = merge(var.tags, {
      Name = "${var.gitlab_runner_config.runners.name}-instance-asg"
    })
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    ignore_changes = [
      desired_capacity
    ]
  }
}

data "aws_ami" "default" {
  most_recent = true
  owners      = ["125523088429"]

  filter {
    name   = "name"
    values = ["fedora-coreos-${var.coreos_version}*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = [var.architecture]
  }
}

resource "aws_launch_template" "default" {
  name_prefix   = var.gitlab_runner_config.runners.name
  image_id      = data.aws_ami.default.id
  instance_type = local.instance_types[0] # Use first instance type as default
  key_name      = aws_key_pair.default.key_name
  user_data     = var.user_data

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      encrypted   = true
      volume_size = var.ebs_volume_size
      volume_type = var.ebs_volume_type
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required" # IMDSv2 required
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.default.id]
  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(var.tags, {
      Name = "${var.gitlab_runner_config.runners.name}-instance"
    })
  }
}

resource "aws_security_group" "default" {
  name_prefix = var.gitlab_runner_config.runners.name
  description = "Security group for GitLab Runner instances"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.gitlab_runner_config.runners.name}-sg"
  })
}

resource "aws_vpc_security_group_egress_rule" "egress" {
  #checkov:skip=CKV_AWS_382:GitLab Runner instances require unrestricted egress for CI/CD operations (GitLab API, container registries, package managers, AWS services, and arbitrary job dependencies)
  #tfsec:ignore:aws-ec2-no-public-egress-sgr GitLab Runner instances require unrestricted egress for CI/CD operations (GitLab API, container registries, package managers, AWS services)

  cidr_ipv4         = "0.0.0.0/0"
  description       = "Allow all outbound traffic for GitLab Runner instances to access GitLab, ECR, S3, and other AWS services"
  ip_protocol       = "-1" # semantically equivalent to all ports
  security_group_id = aws_security_group.default.id

  tags = var.tags
}

resource "aws_vpc_security_group_ingress_rule" "manager" {
  #checkov:skip=CKV_AWS_24:False positive - SSH access is restricted to manager security group only, not 0.0.0.0/0 (uses referenced_security_group_id)

  description                  = "Allow SSH access from GitLab Runner manager for instance provisioning and job execution"
  from_port                    = 22
  ip_protocol                  = "tcp"
  referenced_security_group_id = var.gitlab_manager_security_group_id
  security_group_id            = aws_security_group.default.id
  to_port                      = 22

  tags = var.tags
}

resource "aws_key_pair" "default" {
  key_name_prefix = var.gitlab_runner_config.runners.name
  public_key      = var.public_ssh_key

  tags = var.tags
}
