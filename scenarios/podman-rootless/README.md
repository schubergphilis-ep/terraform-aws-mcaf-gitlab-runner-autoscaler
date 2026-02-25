# GitLab Runner - Podman Rootless Scenario

This scenario deploys a GitLab Runner with **rootless Podman** as the container runtime. This configuration provides enhanced security by running containers without root privileges.

## Features

- **Rootless Podman**: Runs containers as non-root user (`core`)
- **Enhanced Security**: Reduced attack surface without privileged access
- **User Namespaces**: Container isolation using user namespace mapping
- **Production Ready**: Uses ECS Fargate for manager and EC2 Spot instances for executors

## Architecture

- **Manager**: ECS Fargate task running gitlab-runner-autoscaler
- **Executors**: EC2 ARM64 instances (Fedora CoreOS) with rootless Podman
- **Socket**: `/run/user/1000/podman/podman.sock` (rootless)
- **User**: `core` (UID 1000)
- **Scaling**: Automatic based on job demand using AWS Autoscaler plugin

## Limitations

⚠️ **Important**: Rootless mode has some limitations compared to rootful:

- **No privileged mode**: Cannot run privileged containers
- **No Docker-in-Docker**: Building container images requires alternatives (kaniko, buildah)
- **Port binding**: Ports < 1024 require special configuration
- **Volume permissions**: Some volume mounts may have permission issues
- **Nested containers**: Limited support for running containers within containers

## Usage

### Basic Example

```hcl
module "gitlab_runner" {
  source = "schubergphilis/mcaf-gitlab-runner-autoscaler/aws//scenarios/podman-rootless"

  runner_name         = "my-secure-runner"
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
  source = "schubergphilis/mcaf-gitlab-runner-autoscaler/aws//scenarios/podman-rootless"

  runner_name         = "my-secure-runner"
  gitlab_url          = "https://gitlab.example.com"
  gitlab_runner_token = var.gitlab_runner_token

  concurrent_jobs       = 8
  capacity_per_instance = 2
  max_instances         = 15

  # Custom autoscaling policy: keep 1 idle instance during work hours
  autoscaler_policy = [
    {
      idle_count = 1
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
    Security    = "enhanced"
    ManagedBy   = "Terraform"
  }
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

- **Security-sensitive environments**: Enhanced isolation and reduced attack surface
- **Compliance requirements**: Running workloads without root privileges
- **General CI/CD**: Testing, linting, building applications (non-containerized)
- **Multi-tenant environments**: Better isolation between jobs

## Building Container Images (DinD Alternative)

Since rootless mode doesn't support Docker-in-Docker, use these alternatives:

### Option 1: Kaniko (Recommended)

```yaml
build-image:
  image: gcr.io/kaniko-project/executor:latest
  script:
    - echo "{\"auths\":{\"$CI_REGISTRY\":{\"username\":\"$CI_REGISTRY_USER\",\"password\":\"$CI_REGISTRY_PASSWORD\"}}}" > /kaniko/.docker/config.json
    - /kaniko/executor --context $CI_PROJECT_DIR --dockerfile $CI_PROJECT_DIR/Dockerfile --destination $CI_REGISTRY_IMAGE:$CI_COMMIT_TAG
```

### Option 2: Buildah

```yaml
build-image:
  image: quay.io/buildah/stable:latest
  script:
    - buildah bud -t $CI_REGISTRY_IMAGE:$CI_COMMIT_TAG .
    - buildah push --creds $CI_REGISTRY_USER:$CI_REGISTRY_PASSWORD $CI_REGISTRY_IMAGE:$CI_COMMIT_TAG
```

## Security Considerations

- **No privileged mode**: Containers cannot escalate privileges
- **User namespaces**: Container root (UID 0) maps to host UID 1000
- **Limited capabilities**: Reduced kernel capabilities for containers
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

# Note: user is 'core', not 'root'
ssh -i runner_key.pem core@<instance-private-ip>

# Check Podman (as core user)
podman ps
systemctl --user status podman.socket
ls -la /run/user/1000/podman/podman.sock

# Check XDG_RUNTIME_DIR
echo $XDG_RUNTIME_DIR
```

### Common Issues

**Issue**: `permission denied` errors in jobs

**Solution**: Adjust volume mount permissions or use `:z` SELinux label:
```yaml
variables:
  DOCKER_VOLUMES: /path/on/host:/path/in/container:z
```

**Issue**: Cannot bind to port < 1024

**Solution**: Use ports >= 1024 or configure `net.ipv4.ip_unprivileged_port_start`

## Migration from Rootful

Migrating from rootful to rootless requires updating CI/CD pipelines:

1. Remove `privileged: true` from job definitions
2. Replace Docker-in-Docker with Kaniko or Buildah
3. Update volume mount permissions
4. Test jobs thoroughly in rootless environment

## Related Scenarios

- [podman-rootful](../podman-rootful/README.md): Maximum compatibility with privileged mode

## References

- [Podman Rootless Documentation](https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md)
- [Kaniko Documentation](https://github.com/GoogleContainerTools/kaniko)
- [GitLab Runner Autoscaler](https://docs.gitlab.com/runner/executors/docker_autoscaler.html)
