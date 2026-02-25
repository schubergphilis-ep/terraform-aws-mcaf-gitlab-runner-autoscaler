# Tests for the manager module
# Uses mock providers for AWS and TLS — no real credentials needed

mock_provider "aws" {}
mock_provider "tls" {}

override_module {
  target = module.runner_manager
}

variables {
  gitlab_runner_token = "glrt-test-token-12345"
  vpc_id              = "vpc-12345678"
  vpc_subnet_ids      = ["subnet-12345678"]

  gitlab_runner_config = {
    concurrent = 10
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

run "config_generation" {
  command = plan

  assert {
    condition     = jsondecode(aws_secretsmanager_secret_version.config.secret_string).runners[0].token == var.gitlab_runner_token
    error_message = "Runner token should be injected into the config"
  }

  assert {
    condition     = jsondecode(aws_secretsmanager_secret_version.config.secret_string).runners[0].autoscaler.plugin_config.name == "test-runner-instance-asg"
    error_message = "ASG name in plugin_config should follow the naming convention"
  }

  assert {
    condition     = jsondecode(aws_secretsmanager_secret_version.config.secret_string).concurrent == 10
    error_message = "Concurrent setting should be preserved from input"
  }
}

run "naming_convention" {
  command = plan

  assert {
    condition     = startswith(aws_secretsmanager_secret.config.name_prefix, "test-runner")
    error_message = "Secret name_prefix should match the runner name"
  }
}
