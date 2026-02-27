# Tests for the Docker scenario
# Uses mock provider for AWS — ignition provider runs for real

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

override_module {
  target = module.manager.module.runner_manager
  outputs = {
    security_group_id = "sg-mock-runner-manager"
  }
}

override_module {
  target = module.instance.module.security_group
  outputs = {
    id = "sg-mock-instance"
  }
}

variables {
  runner_name         = "test-docker-runner"
  gitlab_url          = "https://gitlab.example.com"
  gitlab_runner_token = "glrt-test-token-12345"
  vpc_id              = "vpc-12345678"
  vpc_subnet_ids      = ["subnet-12345678"]
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

}
