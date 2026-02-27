# GitLab Runner Manager

Deploys the GitLab Runner manager as an ECS Fargate task. The manager polls GitLab for pending CI/CD jobs, provisions EC2 executor instances via an Auto Scaling Group, and connects to them over SSH using EC2 Instance Connect (ephemeral keys). Runner configuration and the GitLab token are stored in AWS Secrets Manager.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 6.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_runner_manager"></a> [runner\_manager](#module\_runner\_manager) | schubergphilis/mcaf-fargate/aws | ~> 2.2.0 |

## Resources

| Name | Type |
|------|------|
| [aws_secretsmanager_secret.config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret) | resource |
| [aws_secretsmanager_secret_version.config](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/secretsmanager_secret_version) | resource |
| [aws_iam_policy_document.task_execution_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_gitlab_runner_config"></a> [gitlab\_runner\_config](#input\_gitlab\_runner\_config) | GitLab Runner configuration for Docker Autoscaler | <pre>object({<br/>    concurrent = number<br/>    runners = object({<br/>      name        = string<br/>      url         = string<br/>      shell       = optional(string, "sh")<br/>      environment = optional(list(string), ["CONTAINER_HOST=unix:///tmp/podman.sock", "DOCKER_HOST=unix:///tmp/podman.sock"])<br/>      executor    = optional(string, "docker-autoscaler")<br/>      builds_dir  = optional(string, "/var/builds")<br/>      docker = object({<br/>        host                         = optional(string, "unix:///run/podman/podman.sock")<br/>        tls_verify                   = optional(bool, false)<br/>        privileged                   = optional(bool, false)<br/>        disable_entrypoint_overwrite = optional(bool, false)<br/>        oom_kill_disable             = optional(bool, false)<br/>        disable_cache                = optional(bool, false)<br/>        volumes                      = optional(list(string), [])<br/>        environment                  = optional(list(string), [])<br/>        image                        = optional(string, "alpine:latest")<br/>      })<br/>      autoscaler = object({<br/>        plugin                = string<br/>        capacity_per_instance = number<br/>        max_use_count         = optional(number, 0)<br/>        max_instances         = number<br/>        plugin_config = optional(object({<br/>          name             = optional(string, "")<br/>          profile          = optional(string, "")<br/>          config_file      = optional(string, "")<br/>          credentials_file = optional(string, "")<br/>        }))<br/>        connector_config = object({<br/>          username          = string<br/>          use_external_addr = bool<br/>        })<br/>        policy = list(object({<br/>          idle_count      = number<br/>          idle_time       = string<br/>          preemptive_mode = optional(bool, true)<br/>          periods         = optional(list(string), [])<br/>          timezone        = optional(string, "Europe/Amsterdam")<br/>        }))<br/>      })<br/>    })<br/>  })</pre> | n/a | yes |
| <a name="input_gitlab_runner_token"></a> [gitlab\_runner\_token](#input\_gitlab\_runner\_token) | GitLab Runner authentication token | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC where the GitLab Runner manager will be deployed | `string` | n/a | yes |
| <a name="input_vpc_subnet_ids"></a> [vpc\_subnet\_ids](#input\_vpc\_subnet\_ids) | List of VPC subnet IDs where the GitLab Runner manager will be deployed | `list(string)` | n/a | yes |
| <a name="input_docker_credential_helpers"></a> [docker\_credential\_helpers](#input\_docker\_credential\_helpers) | Map of Docker registry hostnames to credential helper names, written to the manager's /root/.docker/config.json as credHelpers | `map(string)` | `{}` | no |
| <a name="input_gitlab_runner_command"></a> [gitlab\_runner\_command](#input\_gitlab\_runner\_command) | Command to run the GitLab Runner | `list(string)` | <pre>[<br/>  "run"<br/>]</pre> | no |
| <a name="input_gitlab_runner_image"></a> [gitlab\_runner\_image](#input\_gitlab\_runner\_image) | Container image for the GitLab Runner manager (should be pinned to a specific version or digest) | `string` | `"schubergphilis/gitlab-runner-autoscaler:alpine"` | no |
| <a name="input_kms_key_id"></a> [kms\_key\_id](#input\_kms\_key\_id) | KMS key ID for encrypting Secrets Manager secrets. If not provided, uses AWS managed key (aws/secretsmanager) | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Map of tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | Security group ID of the GitLab Runner manager for allowing instance communication |
<!-- END_TF_DOCS -->