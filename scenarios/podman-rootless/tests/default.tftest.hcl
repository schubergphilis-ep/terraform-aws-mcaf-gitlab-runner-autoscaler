# Tests for the Podman rootless scenario
# Uses mock providers for AWS and TLS — ignition provider runs for real

mock_provider "aws" {
  override_data {
    target = module.instance.data.aws_ec2_instance_types.default
    values = {
      instance_types = ["c7gd.medium", "c7gd.large"]
    }
  }

  override_data {
    target = module.instance.data.aws_ami.default
    values = {
      id           = "ami-12345678"
      architecture = "arm64"
    }
  }
}

mock_provider "tls" {}

override_module {
  target = module.manager.module.runner_manager
  outputs = {
    security_group_id = "sg-mock-runner-manager"
  }
}

variables {
  runner_name          = "test-podman-rootless-runner"
  gitlab_url           = "https://gitlab.example.com"
  gitlab_runner_token  = "glrt-test-token-12345"
  vpc_id               = "vpc-12345678"
  vpc_subnet_ids       = ["subnet-12345678"]
}

run "default_configuration" {
  command = apply

  assert {
    condition     = output.manager_security_group_id != null
    error_message = "manager_security_group_id output should not be null"
  }

  assert {
    condition     = output.instance_security_group_id != null
    error_message = "instance_security_group_id output should not be null"
  }

  assert {
    condition     = output.public_ssh_key != null
    error_message = "public_ssh_key output should not be null"
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

run "invalid_capacity_per_instance" {
  command = plan

  variables {
    capacity_per_instance = 0
  }

  expect_failures = [
    var.capacity_per_instance,
  ]
}
