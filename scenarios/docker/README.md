# GitLab Runner - Docker Scenario

This scenario deploys a GitLab Runner with **Docker API compatibility** using Podman as the container runtime. This configuration provides full Docker compatibility while leveraging Podman's features.

## Important Note

**This scenario uses Podman with Docker socket compatibility**, not native Docker. Podman provides 100% Docker API compatibility through a symlinked socket at `/var/run/docker.sock`. For most CI/CD workloads, this is functionally identical to using Docker directly.

## Features

- **Full Docker API Compatibility**: Works with all Docker commands and tools
- **Privileged Mode Support**: Supports Docker-in-Docker (DinD) workflows
- **Drop-in Replacement**: No changes needed to `.gitlab-ci.yml` files
- **Production Ready**: Uses ECS Fargate for manager and EC2 Spot instances for executors

## Architecture

- **Manager**: ECS Fargate task running gitlab-runner-autoscaler
- **Executors**: EC2 ARM64 instances (Fedora CoreOS) with rootful Podman
- **Socket**: `/var/run/docker.sock` → `/run/podman/podman.sock` (symlink)
- **User**: `root`
- **Container Runtime**: Podman (with Docker API compatibility)
- **Scaling**: Automatic based on job demand using AWS Autoscaler plugin

## Usage

### Basic Example

```hcl
module "gitlab_runner" {
  source = "schubergphilis/mcaf-gitlab-runner-autoscaler/aws//scenarios/docker"

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

### Advanced Example with Custom Scaling Policy

```hcl
module "gitlab_runner" {
  source = "schubergphilis/mcaf-gitlab-runner-autoscaler/aws//scenarios/docker"

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
| concurrent_jobs | Maximum concurrent jobs | `number` | `4` | no |
| capacity_per_instance | Jobs per instance | `number` | `1` | no |
| max_instances | Maximum number of instances | `number` | `5` | no |
| privileged_mode | Enable Docker privileged mode | `bool` | `true` | no |
| autoscaler_policy | Autoscaler idle policy configuration | `list(object)` | See below | no |
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

- **Standard Docker workflows**: CI/CD pipelines using Docker commands
- **Docker-in-Docker (DinD)**: Building container images in CI/CD pipelines
- **Migrating from Docker**: Drop-in replacement for existing Docker-based runners
- **Maximum compatibility**: Works with all standard Docker tooling

## Why Podman Instead of Docker?

We chose Podman over Docker for its superior security architecture:

- **Better Security**: Podman's daemonless architecture eliminates a single point of failure and reduces the attack surface. No privileged daemon running as root in the background.
- **Full Compatibility**: Podman provides 100% Docker API compatibility, so your existing workflows continue to work
- **No Changes Required**: Your `.gitlab-ci.yml` files work as-is with no modifications
- **Rootless Capability**: Podman supports true rootless containers (see [podman-rootless](../podman-rootless/) scenario)
- **Native to Fedora CoreOS**: Podman comes pre-installed and is the container engine of choice for modern container platforms
- **Zero Overhead**: No performance difference for standard workloads

## Security Considerations

- **Privileged mode enabled**: Containers run with elevated privileges
- **Root access**: Podman runs as root user for maximum compatibility
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

# Check Docker compatibility
ls -la /var/run/docker.sock  # Should be symlink to Podman socket
podman ps                     # Shows running containers
systemctl status podman.socket
```

### Verify Docker Commands Work
```bash
# On the runner instance
docker ps                     # Works via Podman
docker info                   # Shows Podman info
docker run hello-world        # Runs containers
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
  source = "./scenarios/docker"

  runner_name         = "my-runner"
  gitlab_url          = "https://gitlab.com"
  gitlab_runner_token = var.token
  vpc_id              = var.vpc_id
  vpc_subnet_ids      = var.subnets
}
```

## Related Scenarios

- [podman-rootful](../podman-rootful/README.md): Same functionality with explicit Podman naming
- [podman-rootless](../podman-rootless/README.md): Enhanced security with rootless Podman
