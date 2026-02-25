# GitLab Runner - Podman Rootful Scenario

This scenario deploys a GitLab Runner with **rootful Podman** as the container runtime. This configuration provides maximum compatibility with Docker workflows and supports privileged containers.

## Features

- **Rootful Podman**: Runs containers as root with full privileges
- **Privileged Mode**: Supports Docker-in-Docker (DinD) workflows
- **Full Compatibility**: Works with most Docker images and configurations
- **Production Ready**: Uses ECS Fargate for manager and EC2 Spot instances for executors

## Architecture

- **Manager**: ECS Fargate task running a [custom wrapper image](https://github.com/schubergphilis-ep/gitlab-runner-autoscaler-image) around `gitlab/gitlab-runner`. You can provide your own image via `gitlab_runner_image`
- **Executors**: EC2 ARM64 instances (Fedora CoreOS) with rootful Podman
- **Socket**: `/run/podman/podman.sock` (rootful)
- **User**: `root`
- **Scaling**: Automatic based on job demand using AWS Autoscaler plugin

## Usage

### Basic Example

```hcl
module "gitlab_runner" {
  source = "schubergphilis/mcaf-gitlab-runner-autoscaler/aws//scenarios/podman-rootful"

  runner_name         = "my-arm-runner"
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

### x86_64 Architecture Example

```hcl
module "gitlab_runner" {
  source = "schubergphilis/mcaf-gitlab-runner-autoscaler/aws//scenarios/podman-rootful"

  architecture        = "x86_64"  # Use x86_64 instead of ARM64
  runner_name         = "my-x86-runner"
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

### Advanced Example with Custom Scaling Policy

```hcl
module "gitlab_runner" {
  source = "schubergphilis/mcaf-gitlab-runner-autoscaler/aws//scenarios/podman-rootful"

  runner_name         = "my-arm-runner"
  gitlab_url          = "https://gitlab.example.com"
  gitlab_runner_token = var.gitlab_runner_token

  concurrent_jobs       = 10
  capacity_per_instance = 2
  max_instances         = 20
  privileged_mode       = true

  # Custom autoscaling policy: keep 2 idle instances during work hours
  autoscaler_policy = [
    {
      idle_count = 2
      idle_time  = "10m"
      periods    = ["0 9-17 * * mon-fri"] # Work hours
      timezone   = "America/New_York"
    },
    {
      idle_count = 0
      idle_time  = "5m"
      periods    = ["* * * * *"] # All other times
    }
  ]

  vpc_id         = "vpc-12345678"
  vpc_subnet_ids = ["subnet-12345678", "subnet-87654321", "subnet-11111111"]

  tags = {
    Environment = "production"
    Project     = "CI/CD"
    ManagedBy   = "Terraform"
  }
}

output "ssh_key" {
  description = "SSH key for debugging runner instances"
  value       = module.gitlab_runner.public_ssh_key
  sensitive   = true
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.10.0 |
| aws | ~> 6.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| runner_name | Name prefix for the GitLab Runner and AWS resources | `string` | n/a | yes |
| gitlab_url | GitLab instance URL (e.g., https://gitlab.com) | `string` | n/a | yes |
| gitlab_runner_token | GitLab Runner registration token | `string` | n/a | yes |
| vpc_id | VPC ID where infrastructure will be deployed | `string` | n/a | yes |
| vpc_subnet_ids | List of subnet IDs | `list(string)` | n/a | yes |
| architecture | CPU architecture (arm64 or x86_64) | `string` | `"arm64"` | no |
| concurrent_jobs | Maximum concurrent jobs | `number` | `4` | no |
| capacity_per_instance | Jobs per instance | `number` | `1` | no |
| max_instances | Maximum number of instances | `number` | `5` | no |
| privileged_mode | Enable Docker privileged mode | `bool` | `true` | no |
| autoscaler_policy | Autoscaler idle policy configuration | `list(object)` | See below | no |
| docker_credential_helpers | Map of registry hostnames to credential helper names | `map(string)` | `{}` | no |
| instance_types | List of instance types (dynamically discovered from AWS if not specified) | `list(string)` | `null` | no |
| tags | Tags to apply to all resources | `map(string)` | `{}` | no |

### Default Autoscaler Policy

```hcl
[
  {
    idle_count = 0
    idle_time  = "5m"
    periods    = ["* * * * *"]
  }
]
```

## Outputs

| Name | Description |
|------|-------------|
| manager_security_group_id | Security group ID of the GitLab Runner manager |
| public_ssh_key | Public SSH key for accessing runner instances |

## Use Cases

This scenario is ideal for:

- **Docker-in-Docker (DinD) workflows**: Building container images in CI/CD pipelines
- **Privileged operations**: Tasks requiring elevated permissions
- **Maximum compatibility**: Running legacy Docker configurations
- **Testing and development**: Quick setup with broad compatibility

## Security Considerations

- **Privileged mode enabled**: Containers run with elevated privileges
- **Root access**: Podman runs as root user
- **Network isolation**: Instances use private subnets with security groups
- **Secrets management**: Runner config stored in AWS Secrets Manager
- **SSH access**: Only the manager security group has SSH ingress by default. To troubleshoot instances, add an ingress rule for your bastion host, VPN, or use AWS Systems Manager Session Manager.

## Debugging

### View Manager Logs
```bash
# Find ECS task
aws ecs list-tasks --cluster <cluster-name>

# View logs in CloudWatch
aws logs tail /aws/ecs/<cluster-name> --follow
```

### SSH to Runner Instance

Instances run on private subnets with SSH restricted to the manager security group. To connect for troubleshooting, add a temporary ingress rule to the instance security group (output: `instance_security_group_id`) for your bastion or VPN, then:

```bash
# Get SSH key from Terraform output
terraform output -raw ssh_key > runner_key.pem
chmod 600 runner_key.pem

ssh -i runner_key.pem root@<instance-private-ip>

# Check Podman
podman ps
systemctl status podman.socket
ls -la /run/podman/podman.sock
```

## Migration from Root Module

If you're currently using the root module directly, migration is straightforward:

**Before:**
```hcl
module "manager" {
  source = "./modules/manager"
  # ...
}

module "instance" {
  source = "./modules/instance"
  # ...
}
```

**After:**
```hcl
module "gitlab_runner" {
  source = "./scenarios/podman-rootful"

  runner_name         = "my-runner"
  gitlab_url          = "https://gitlab.com"
  gitlab_runner_token = var.token
  vpc_id              = var.vpc_id
  vpc_subnet_ids      = var.subnets
}
```

## Related Scenarios

- [podman-rootless](../podman-rootless/README.md): Enhanced security with rootless Podman

## References

- [GitLab Runner Autoscaler](https://docs.gitlab.com/runner/runner_autoscale/gitlab-runner-autoscaler/) — Official documentation on autoscaling architecture, configuration, and supported platforms
- [Manager wrapper image](https://github.com/schubergphilis-ep/gitlab-runner-autoscaler-image) — Custom Docker image with AWS integration used by the manager
