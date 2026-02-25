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

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_autoscaling_group.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_key_pair.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/key_pair) | resource |
| [aws_launch_template.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_security_group.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_vpc_security_group_egress_rule.egress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_egress_rule) | resource |
| [aws_vpc_security_group_ingress_rule.manager](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_ami.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_ec2_instance_types.default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ec2_instance_types) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_gitlab_manager_security_group_id"></a> [gitlab\_manager\_security\_group\_id](#input\_gitlab\_manager\_security\_group\_id) | Security group ID of the GitLab Runner manager for SSH access to instances | `string` | n/a | yes |
| <a name="input_gitlab_runner_config"></a> [gitlab\_runner\_config](#input\_gitlab\_runner\_config) | GitLab Runner configuration for Docker Autoscaler | <pre>object({<br/>    concurrent = number<br/>    runners = object({<br/>      name        = string<br/>      url         = string<br/>      shell       = optional(string, "sh")<br/>      environment = optional(list(string), ["CONTAINER_HOST=unix:///tmp/podman.sock", "DOCKER_HOST=unix:///tmp/podman.sock"])<br/>      executor    = optional(string, "docker-autoscaler")<br/>      builds_dir  = optional(string, "/var/builds")<br/>      docker = object({<br/>        host                         = optional(string, "unix:///run/podman/podman.sock")<br/>        tls_verify                   = optional(bool, false)<br/>        privileged                   = optional(bool, false)<br/>        disable_entrypoint_overwrite = optional(bool, false)<br/>        oom_kill_disable             = optional(bool, false)<br/>        disable_cache                = optional(bool, false)<br/>        volumes                      = optional(list(string), ["/run/podman/podman.sock:/tmp/podman.sock:z", "/etc/builds:/etc/builds", "/cache"])<br/>        environment                  = optional(list(string), [])<br/>        image                        = optional(string, "alpine:latest")<br/>      })<br/>      autoscaler = object({<br/>        plugin                = string<br/>        capacity_per_instance = number<br/>        max_use_count         = optional(number, 0)<br/>        max_instances         = number<br/>        plugin_config = optional(object({<br/>          name             = optional(string, "")<br/>          profile          = optional(string, "")<br/>          config_file      = optional(string, "")<br/>          credentials_file = optional(string, "")<br/>        }))<br/>        connector_config = object({<br/>          username               = string<br/>          use_static_credentials = optional(bool, false)<br/>          use_external_addr      = bool<br/>        })<br/>        policy = list(object({<br/>          idle_count      = number<br/>          idle_time       = string<br/>          preemptive_mode = optional(bool, true)<br/>          periods         = optional(list(string), [])<br/>          timezone        = optional(string, "Europe/Amsterdam")<br/>        }))<br/>      })<br/>    })<br/>  })</pre> | n/a | yes |
| <a name="input_public_ssh_key"></a> [public\_ssh\_key](#input\_public\_ssh\_key) | Map of public SSH keys for the runners | `string` | n/a | yes |
| <a name="input_user_data"></a> [user\_data](#input\_user\_data) | Base64-encoded Ignition configuration for instance initialization | `string` | n/a | yes |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | ID of the VPC where the runner instances will be deployed | `string` | n/a | yes |
| <a name="input_vpc_subnet_ids"></a> [vpc\_subnet\_ids](#input\_vpc\_subnet\_ids) | List of VPC subnet IDs where runner instances will be deployed | `list(string)` | n/a | yes |
| <a name="input_architecture"></a> [architecture](#input\_architecture) | CPU architecture for the runner instances (arm64 or x86\_64) | `string` | `"arm64"` | no |
| <a name="input_coreos_version"></a> [coreos\_version](#input\_coreos\_version) | Fedora CoreOS major version to use for the AMI | `string` | `"43"` | no |
| <a name="input_ebs_volume_size"></a> [ebs\_volume\_size](#input\_ebs\_volume\_size) | Size of the EBS root volume in GB | `number` | `200` | no |
| <a name="input_ebs_volume_type"></a> [ebs\_volume\_type](#input\_ebs\_volume\_type) | Type of EBS volume (gp3, gp2, io1, io2) | `string` | `"gp3"` | no |
| <a name="input_instance_types"></a> [instance\_types](#input\_instance\_types) | List of instance types to use in the ASG (ordered by preference). If not specified, automatically queries AWS for current-generation compute-optimized instances with instance storage matching the selected architecture | `list(string)` | `null` | no |
| <a name="input_on_demand_base_capacity"></a> [on\_demand\_base\_capacity](#input\_on\_demand\_base\_capacity) | Absolute minimum number of on-demand instances | `number` | `0` | no |
| <a name="input_on_demand_percentage_above_base"></a> [on\_demand\_percentage\_above\_base](#input\_on\_demand\_percentage\_above\_base) | Percentage of on-demand instances above base capacity (0-100, where 0 = 100% spot) | `number` | `0` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Map of tags to apply to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_autoscaling_group_arn"></a> [autoscaling\_group\_arn](#output\_autoscaling\_group\_arn) | ARN of the Auto Scaling Group for GitLab Runner instances |
| <a name="output_autoscaling_group_name"></a> [autoscaling\_group\_name](#output\_autoscaling\_group\_name) | Name of the Auto Scaling Group for GitLab Runner instances |
| <a name="output_launch_template_id"></a> [launch\_template\_id](#output\_launch\_template\_id) | ID of the launch template used by the Auto Scaling Group |
| <a name="output_security_group_id"></a> [security\_group\_id](#output\_security\_group\_id) | ID of the security group attached to runner instances |
<!-- END_TF_DOCS -->