# Tests for the instance module
# Uses mock provider for AWS with data source overrides

mock_provider "aws" {
  override_data {
    target = data.aws_ec2_instance_types.default
    values = {
      instance_types = ["c7gd.medium", "c7gd.large"]
    }
  }

  override_data {
    target = data.aws_ami.default
    values = {
      id           = "ami-12345678"
      architecture = "arm64"
    }
  }
}

override_module {
  target = module.security_group
  outputs = {
    id = "sg-mock-instance"
  }
}

variables {
  gitlab_manager_security_group_id = "sg-manager-12345"
  user_data                        = "e30=" # base64 encoded "{}"
  vpc_id                           = "vpc-12345678"
  vpc_subnet_ids                   = ["subnet-12345678"]

  gitlab_runner_config = {
    concurrent = 4
    runners = {
      name = "test-runner"
      url  = "https://gitlab.example.com"
      docker = {
        host = "unix:///run/podman/podman.sock"
      }
      autoscaler = {
        plugin                = "aws"
        capacity_per_instance = 1
        max_instances         = 5
        connector_config = {
          username          = "root"
          use_external_addr = false
        }
        policy = [
          {
            idle_count = 0
            idle_time  = "5m"
          }
        ]
      }
    }
  }
}

run "default_configuration" {
  command = plan

  assert {
    condition     = aws_autoscaling_group.default.name == "test-runner-instance-asg"
    error_message = "ASG name should follow the naming convention"
  }

  assert {
    condition     = aws_autoscaling_group.default.min_size == 0
    error_message = "ASG min_size should be 0"
  }

  assert {
    condition     = aws_autoscaling_group.default.desired_capacity == 0
    error_message = "ASG desired_capacity should be 0"
  }

  assert {
    condition     = aws_launch_template.default.block_device_mappings[0].ebs[0].encrypted == "true"
    error_message = "Launch template EBS should be encrypted"
  }

  assert {
    condition     = aws_launch_template.default.metadata_options[0].http_tokens == "required"
    error_message = "Launch template should require IMDSv2"
  }
}

run "custom_instance_types" {
  command = plan

  variables {
    instance_types = ["c7g.medium"]
  }

  assert {
    condition     = aws_launch_template.default.instance_type == "c7g.medium"
    error_message = "Launch template should use the custom instance type"
  }
}

run "invalid_architecture" {
  command = plan

  variables {
    architecture = "mips64"
  }

  expect_failures = [
    var.architecture,
  ]
}

run "invalid_ebs_volume_type" {
  command = plan

  variables {
    ebs_volume_type = "standard"
  }

  expect_failures = [
    var.ebs_volume_type,
  ]
}

run "invalid_on_demand_percentage" {
  command = plan

  variables {
    on_demand_percentage_above_base = 150
  }

  expect_failures = [
    var.on_demand_percentage_above_base,
  ]
}
