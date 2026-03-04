# GitLab Runner - Podman Rootful Scenario

Deploys a GitLab Runner with **rootful Podman** as the container runtime. Provides maximum compatibility with Docker workflows and supports privileged containers using the native Podman socket.

## Features

- **Rootful Podman**: Runs containers as root with full privileges
- **Privileged Mode**: Supports Docker-in-Docker (DinD) workflows
- **Full Compatibility**: Works with most Docker images and configurations

## Architecture

- **Manager**: ECS Fargate task running a [custom wrapper image](https://github.com/schubergphilis-ep/gitlab-runner-autoscaler-image) around `gitlab/gitlab-runner`. You can provide your own image via `gitlab_runner_image`
- **Executors**: EC2 ARM64 instances (Fedora CoreOS) with rootful Podman
- **Socket**: `/run/podman/podman.sock` (rootful)
- **User**: `root`

## Usage

```hcl
module "gitlab_runner" {
  source = "schubergphilis/mcaf-gitlab-runner-autoscaler/aws//scenarios/podman-rootful"

  runner_name         = "my-runner"
  gitlab_url          = "https://gitlab.com"
  gitlab_runner_token = var.gitlab_runner_token

  vpc_id         = "vpc-12345678"
  vpc_subnet_ids = ["subnet-12345678", "subnet-87654321"]

  tags = {
    Environment = "production"
    Project     = "CI/CD"
  }
}
```

See the [scenarios README](../README.md) for comparisons, autoscaling policy examples, debugging instructions, and migration guides.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.0 |
| <a name="requirement_ignition"></a> [ignition](#requirement\_ignition) | >= 2.1 |

## Providers

No providers.

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ignition"></a> [ignition](#module\_ignition) | ../../modules/ignition/podman-rootful | n/a |
| <a name="module_instance"></a> [instance](#module\_instance) | ../../modules/instance | n/a |
| <a name="module_manager"></a> [manager](#module\_manager) | ../../modules/manager | n/a |

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_gitlab_runner_token"></a> [gitlab\_runner\_token](#input\_gitlab\_runner\_token) | GitLab Runner registration token for authenticating the runner with GitLab | `string` | n/a | yes |
| <a name="input_gitlab_url"></a> [gitlab\_url](#input\_gitlab\_url) | GitLab instance URL (e.g., https://gitlab.com) | `string` | n/a | yes |
| <a name="input_runner_name"></a> [runner\_name](#input\_runner\_name) | Name prefix for the GitLab Runner and AWS resources | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC ID where the GitLab Runner infrastructure will be deployed | `string` | n/a | yes |
| <a name="input_vpc_subnet_ids"></a> [vpc\_subnet\_ids](#input\_vpc\_subnet\_ids) | List of subnet IDs for deploying the manager and instances | `list(string)` | n/a | yes |
| <a name="input_architecture"></a> [architecture](#input\_architecture) | CPU architecture for GitLab Runner (arm64 or x86\_64) | `string` | `"arm64"` | no |
| <a name="input_autoscaler_policy"></a> [autoscaler\_policy](#input\_autoscaler\_policy) | Autoscaler idle policy configuration | <pre>list(object({<br/>    idle_count      = number<br/>    idle_time       = string<br/>    preemptive_mode = optional(bool, true)<br/>    periods         = optional(list(string), [])<br/>    timezone        = optional(string, "Europe/Amsterdam")<br/>  }))</pre> | <pre>[<br/>  {<br/>    "idle_count": 0,<br/>    "idle_time": "5m",<br/>    "periods": [<br/>      "* * * * *"<br/>    ]<br/>  }<br/>]</pre> | no |
| <a name="input_capacity_per_instance"></a> [capacity\_per\_instance](#input\_capacity\_per\_instance) | Number of jobs each instance can handle concurrently | `number` | `1` | no |
| <a name="input_concurrent_jobs"></a> [concurrent\_jobs](#input\_concurrent\_jobs) | Maximum number of concurrent jobs the runner can handle | `number` | `4` | no |
| <a name="input_docker_credential_helpers"></a> [docker\_credential\_helpers](#input\_docker\_credential\_helpers) | Map of Docker registry hostnames to credential helper names, written to the manager's /root/.docker/config.json as credHelpers | `map(string)` | `{}` | no |
| <a name="input_ebs_volume_size"></a> [ebs\_volume\_size](#input\_ebs\_volume\_size) | Size of the EBS root volume in GB. Defaults to 200 | `number` | `null` | no |
| <a name="input_ebs_volume_type"></a> [ebs\_volume\_type](#input\_ebs\_volume\_type) | Type of EBS volume (gp3, gp2, io1, io2). Defaults to gp3 | `string` | `null` | no |
| <a name="input_gitlab_runner_image"></a> [gitlab\_runner\_image](#input\_gitlab\_runner\_image) | Container image for the GitLab Runner manager (should be pinned to a specific version or digest) | `string` | `null` | no |
| <a name="input_instance_types"></a> [instance\_types](#input\_instance\_types) | List of EC2 instance types to use (ordered by preference). If not specified, automatically discovers current-generation compute-optimized instances with instance storage for the selected architecture | `list(string)` | `null` | no |
| <a name="input_kms_key_id"></a> [kms\_key\_id](#input\_kms\_key\_id) | Optional KMS key ID for encrypting Secrets Manager secrets. If not provided, uses AWS managed key | `string` | `null` | no |
| <a name="input_max_instances"></a> [max\_instances](#input\_max\_instances) | Maximum number of instances the autoscaler can create | `number` | `5` | no |
| <a name="input_on_demand_base_capacity"></a> [on\_demand\_base\_capacity](#input\_on\_demand\_base\_capacity) | Absolute minimum number of on-demand instances. Defaults to 0 (all spot) | `number` | `null` | no |
| <a name="input_on_demand_percentage_above_base"></a> [on\_demand\_percentage\_above\_base](#input\_on\_demand\_percentage\_above\_base) | Percentage of on-demand instances above base capacity (0-100). Defaults to 0 (100% spot) | `number` | `null` | no |
| <a name="input_os_auto_updates"></a> [os\_auto\_updates](#input\_os\_auto\_updates) | OS auto-updater (Zincati) configuration for Fedora CoreOS instances. Set enabled=false to disable auto-updates entirely, or use strategy='periodic' with maintenance\_windows to control when updates are applied. | <pre>object({<br/>    enabled  = optional(bool, true)<br/>    strategy = optional(string, "immediate") # immediate or periodic<br/>    maintenance_windows = optional(list(object({<br/>      days           = list(string) # ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]<br/>      start_time     = string       # "22:00" (UTC)<br/>      length_minutes = number       # 60<br/>    })), [])<br/>  })</pre> | `{}` | no |
| <a name="input_privileged_mode"></a> [privileged\_mode](#input\_privileged\_mode) | Enable Docker privileged mode for runners (required for Docker-in-Docker) | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_instance_security_group_id"></a> [instance\_security\_group\_id](#output\_instance\_security\_group\_id) | Security group ID of the GitLab Runner instance |
| <a name="output_manager_security_group_id"></a> [manager\_security\_group\_id](#output\_manager\_security\_group\_id) | Security group ID of the GitLab Runner manager |
<!-- END_TF_DOCS -->
