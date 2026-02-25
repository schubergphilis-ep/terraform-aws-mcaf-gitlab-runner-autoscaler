# GitLab Runner Scenarios

This directory contains pre-configured scenario modules that make it easy to deploy GitLab Runners with different container runtime configurations. Each scenario is a complete, ready-to-use Terraform module that wraps the base `manager` and `instance` modules with opinionated defaults.

## Why Podman?

All scenarios use **Podman** as the container runtime for superior security:

- **Daemonless Architecture**: No privileged background daemon, reducing attack surface
- **Enhanced Security**: Eliminates the single point of failure that Docker's daemon represents
- **Full Compatibility**: 100% Docker API compatible - existing workflows work unchanged
- **Rootless Capable**: Native support for running containers without root privileges
- **Modern Default**: Podman is the container engine of choice for security-focused platforms

The "docker" scenario provides full Docker API compatibility for seamless migrations, while maintaining Podman's security benefits.

## Available Scenarios

### 🐳 [Docker](./docker/)

Podman with **full Docker API compatibility** - perfect for Docker migrations.

**Best for:**
- Migrating from Docker-based runners
- Teams familiar with Docker terminology
- Standard Docker-in-Docker workflows
- Drop-in replacement for existing Docker setups

**Key features:**
- ✅ 100% Docker API compatible
- ✅ Privileged mode supported
- ✅ Docker-in-Docker works out of the box
- ✅ Works with existing `.gitlab-ci.yml` files
- ✅ `/var/run/docker.sock` symlink for maximum compatibility
- ⚠️ Runs as root user

[Read more →](./docker/README.md)

---

### 🔓 [Podman Rootful](./podman-rootful/)

Runs containers with **root privileges** for maximum compatibility.

**Best for:**
- Docker-in-Docker (DinD) workflows
- Building container images in CI/CD
- Legacy applications requiring privileged access
- Development and testing environments

**Key features:**
- ✅ Privileged mode supported
- ✅ Full Docker compatibility
- ✅ Docker-in-Docker works out of the box
- ⚠️ Runs as root user
- ℹ️ Uses native Podman socket (no Docker socket symlink)

[Read more →](./podman-rootful/README.md)

---

### 🔒 [Podman Rootless](./podman-rootless/)

Runs containers **without root privileges** for enhanced security.

**Best for:**
- Security-sensitive environments
- Compliance requirements
- General CI/CD (testing, building, deploying apps)
- Multi-tenant workloads

**Key features:**
- ✅ Enhanced security posture
- ✅ Better container isolation
- ✅ Reduced attack surface
- ⚠️ No privileged mode
- ⚠️ No Docker-in-Docker (use Kaniko/Buildah instead)

[Read more →](./podman-rootless/README.md)

---

## Quick Start

### 1. Choose Your Scenario

| Requirement | Recommended Scenario |
|-------------|---------------------|
| Migrating from Docker? | Use **docker** |
| Need to build Docker images? | Use **docker** or **podman-rootful** OR use rootless with Kaniko |
| Need Docker-in-Docker? | Use **docker** or **podman-rootful** |
| Security/compliance critical? | Use **podman-rootless** |
| Maximum compatibility needed? | Use **docker** or **podman-rootful** |
| General CI/CD (no DinD)? | Use **podman-rootless** |
| Prefer Podman terminology? | Use **podman-rootful** or **podman-rootless** |

### 2. Deploy

```hcl
module "gitlab_runner" {
  source = "schubergphilis/mcaf-gitlab-runner-autoscaler/aws//scenarios/docker"
  # OR
  # source = "schubergphilis/mcaf-gitlab-runner-autoscaler/aws//scenarios/podman-rootful"
  # OR
  # source = "schubergphilis/mcaf-gitlab-runner-autoscaler/aws//scenarios/podman-rootless"

  runner_name         = "my-runner"
  gitlab_url          = "https://gitlab.com"
  gitlab_runner_token = var.gitlab_runner_token

  vpc_id         = "vpc-12345678"
  vpc_subnet_ids = ["subnet-12345678", "subnet-87654321"]

  tags = {
    Environment = "production"
  }
}
```

### 3. Apply

```bash
terraform init
terraform plan
terraform apply
```

## Comparison Matrix

| Feature | Docker | Podman Rootful | Podman Rootless |
|---------|--------|----------------|-----------------|
| **Use Case** | Docker migrations | Podman preference | Security-focused |
| **Security** | Standard | Standard | Enhanced ⭐ |
| **Privileged mode** | ✅ Yes | ✅ Yes | ❌ No |
| **Docker-in-Docker** | ✅ Yes | ✅ Yes | ❌ No (use alternatives) |
| **User** | `root` | `root` | `core` (non-root) |
| **Podman socket** | `/run/podman/podman.sock` | `/run/podman/podman.sock` | `/run/user/1000/podman/podman.sock` |
| **Docker socket symlink** | ✅ `/var/run/docker.sock` | ❌ No | ❌ No |
| **Docker compatibility** | 100% (maximum) | 100% | ~90% |
| **Port binding <1024** | ✅ Yes | ✅ Yes | ⚠️ Requires config |
| **Production ready** | ✅ Yes | ✅ Yes | ✅ Yes |
| **Compliance-friendly** | ⚠️ Moderate | ⚠️ Moderate | ✅ High |

**Key Difference:** The `docker` scenario creates a `/var/run/docker.sock` symlink for maximum Docker compatibility, while `podman-rootful` uses only the native Podman socket path. Both are functionally similar and use rootful Podman.

## Architecture

All three scenarios use the same underlying architecture:

```
┌───────────────────────────────────────────────────────────┐
│ AWS VPC                                                   │
│                                                           │
│ ┌───────────────────────────────────────────────────────┐ │
│ │ ECS Fargate (Manager)                                 │ │
│ │ ┌────────────────────────────────────────────┐        │ │
│ │ │ gitlab-runner-autoscaler                   │        │ │
│ │ │ - Manages job queue                        │        │ │
│ │ │ - Scales EC2 instances                     │        │ │
│ │ │ - Monitors autoscaler policy               │        │ │
│ │ └────────────────────────────────────────────┘        │ │
│ └───────────────────────────────────────────────────────┘ │
│                           ▼                               │
│ ┌───────────────────────────────────────────────────────┐ │
│ │ Auto Scaling Group (Executors)                        │ │
│ │                                                       │ │
│ │  ┌──────────┐  ┌──────────┐  ┌──────────┐             │ │
│ │  │ EC2 Spot │  │ EC2 Spot │  │ EC2 Spot │  ...        │ │
│ │  │ ARM64    │  │ ARM64    │  │ ARM64    │             │ │
│ │  │ Fedora   │  │ Fedora   │  │ Fedora   │             │ │
│ │  │ CoreOS   │  │ CoreOS   │  │ CoreOS   │             │ │
│ │  │          │  │          │  │          │             │ │
│ │  │ Podman   │  │ Podman   │  │ Podman   │             │ │
│ │  │ rootful/ │  │ rootful/ │  │ rootful/ │             │ │
│ │  │ rootless │  │ rootless │  │ rootless │             │ │
│ │  └──────────┘  └──────────┘  └──────────┘             │ │
│ │                                                       │ │
│ │  Scales: 0 → max_instances based on job demand        │ │
│ └───────────────────────────────────────────────────────┘ │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

The **only difference** between scenarios is the Podman configuration:
- **Docker & Podman Rootful**: Podman runs as root, socket at `/run/podman/podman.sock`, Docker socket symlinked at `/var/run/docker.sock`
- **Podman Rootless**: Podman runs as `core` user, socket at `/run/user/1000/podman/podman.sock`, no Docker socket symlink

## Common Variables

All scenarios share these common variables:

| Variable | Description | Required |
|----------|-------------|----------|
| `runner_name` | Name prefix for runner and AWS resources | ✅ Yes |
| `gitlab_url` | GitLab instance URL | ✅ Yes |
| `gitlab_runner_token` | Runner registration token | ✅ Yes |
| `vpc_id` | VPC ID | ✅ Yes |
| `vpc_subnet_ids` | List of subnet IDs | ✅ Yes |
| `concurrent_jobs` | Max concurrent jobs (default: 4) | No |
| `capacity_per_instance` | Jobs per instance (default: 1) | No |
| `max_instances` | Max EC2 instances (default: 5) | No |
| `autoscaler_policy` | Scaling policy config | No |
| `tags` | Resource tags | No |

## Autoscaling Policy Examples

### Keep Idle Instances During Work Hours

```hcl
autoscaler_policy = [
  {
    idle_count = 2
    idle_time  = "10m"
    periods    = ["0 9-17 * * mon-fri"]
    timezone   = "America/New_York"
  },
  {
    idle_count = 0
    idle_time  = "5m"
    periods    = ["* * * * *"]
  }
]
```

### Aggressive Scaling (No Idle)

```hcl
autoscaler_policy = [
  {
    idle_count = 0
    idle_time  = "2m"
    periods    = ["* * * * *"]
  }
]
```

### Weekend Warmup

```hcl
autoscaler_policy = [
  {
    idle_count = 5
    idle_time  = "15m"
    periods    = ["0 0-23 * * sat-sun"]
  }
]
```

## Building Container Images

### With Rootful Scenario

Docker-in-Docker works out of the box:

```yaml
build:
  image: docker:latest
  services:
    - docker:dind
  script:
    - docker build -t $CI_REGISTRY_IMAGE:$CI_COMMIT_TAG .
    - docker push $CI_REGISTRY_IMAGE:$CI_COMMIT_TAG
```

### With Rootless Scenario

Use Kaniko (recommended) or Buildah:

```yaml
build:
  image: gcr.io/kaniko-project/executor:latest
  script:
    - echo "{\"auths\":{\"$CI_REGISTRY\":{\"username\":\"$CI_REGISTRY_USER\",\"password\":\"$CI_REGISTRY_PASSWORD\"}}}" > /kaniko/.docker/config.json
    - /kaniko/executor --context $CI_PROJECT_DIR --dockerfile $CI_PROJECT_DIR/Dockerfile --destination $CI_REGISTRY_IMAGE:$CI_COMMIT_TAG
```

## Cost Optimization

Both scenarios use:
- **100% EC2 Spot Instances**: Up to 90% cost savings vs On-Demand
- **ARM64 Architecture**: ~20% cheaper than x86_64
- **Autoscaling**: Instances scale to zero when idle
- **Idle Policy**: Configurable to minimize waste

**Typical monthly cost** (assuming 8 hours/day usage, 5 days/week):
- ~$30-50/month for light usage (1-2 instances average)
- ~$100-150/month for moderate usage (5-10 instances average)

## Migrating Between Scenarios

Switching between scenarios is straightforward:

### Between Docker and Podman Rootful
These are functionally identical, so you can switch with no changes:
```hcl
# FROM
source = "schubergphilis/mcaf-gitlab-runner-autoscaler/aws//scenarios/docker"
# TO
source = "schubergphilis/mcaf-gitlab-runner-autoscaler/aws//scenarios/podman-rootful"
```

### To/From Podman Rootless

1. **Update module source**:
   ```hcl
   source = "schubergphilis/mcaf-gitlab-runner-autoscaler/aws//scenarios/podman-rootless"
   ```

2. **Update CI/CD pipelines** (if moving to rootless):
   - Remove Docker-in-Docker jobs
   - Add Kaniko/Buildah for image builds
   - Add `:z` suffix to volume mounts for SELinux compatibility

3. **Apply changes**:
   ```bash
   terraform apply
   ```

## Troubleshooting

### Manager Not Starting Jobs

1. Check ECS task logs in CloudWatch
2. Verify `gitlab_runner_token` is valid
3. Check security group allows outbound to GitLab URL

### Instances Not Scaling

1. Check Auto Scaling Group activity
2. Verify IAM permissions for manager
3. Check autoscaler policy configuration

### Jobs Failing (Rootless)

1. Check for privileged mode requirements
2. Verify volume mount permissions (add `:z` label)
3. Consider migrating to rootful or using Kaniko

## Support

- **Issues**: [GitHub Issues](https://github.com/your-org/your-repo/issues)
- **Documentation**: See individual scenario READMEs
- **Base Modules**: See `/modules/manager` and `/modules/instance`

## Contributing

To add a new scenario:

1. Create a new directory under `scenarios/`
2. Add `main.tf`, `variables.tf`, `outputs.tf`, `terraform.tf`
3. Write comprehensive `README.md`
4. Update this index README
5. Test thoroughly

## License

See repository LICENSE file.
