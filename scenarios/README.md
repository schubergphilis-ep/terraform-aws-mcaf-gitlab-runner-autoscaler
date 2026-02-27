# GitLab Runner Scenarios

Pre-configured, ready-to-use Terraform modules that wrap the base `manager`, `instance`, and `ignition` modules with opinionated defaults. Each scenario is a complete Terraform module — pick one, provide your GitLab token and VPC details, and apply.

## Why Podman?

All scenarios use **Podman** as the container runtime:

- **Daemonless Architecture**: No privileged background daemon, reducing attack surface
- **Full Compatibility**: 100% Docker API compatible — existing workflows work unchanged
- **Rootless Capable**: Native support for running containers without root privileges
- **Native to Fedora CoreOS**: Pre-installed and the default container engine

The "docker" scenario provides a Docker socket symlink for seamless migrations.

## Available Scenarios

### [Docker](./docker/)

Podman with **full Docker API compatibility** — perfect for Docker migrations.

- 100% Docker API compatible (`/var/run/docker.sock` symlink)
- Privileged mode and Docker-in-Docker supported
- Works with existing `.gitlab-ci.yml` files unchanged
- Runs as `root`

### [Podman Rootful](./podman-rootful/)

Runs containers with **root privileges** using native Podman socket.

- Privileged mode and Docker-in-Docker supported
- Native Podman socket (no Docker socket symlink)
- Runs as `root`

### [Podman Rootless](./podman-rootless/)

Runs containers **without root privileges** for enhanced security.

- Enhanced security posture and container isolation
- No privileged mode or Docker-in-Docker (use Kaniko/Buildah instead)
- Runs as `core` (UID 1000)

## Quick Start

```hcl
module "gitlab_runner" {
  source = "schubergphilis/mcaf-gitlab-runner-autoscaler/aws//scenarios/docker"

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

## Comparison Matrix

| Feature | Docker | Podman Rootful | Podman Rootless |
|---------|--------|----------------|-----------------|
| **Use Case** | Docker migrations | Native Podman | Security-focused |
| **Privileged mode** | Yes | Yes | No |
| **Docker-in-Docker** | Yes | Yes | No (use alternatives) |
| **User** | `root` | `root` | `core` (non-root) |
| **Docker socket symlink** | Yes | No | No |
| **Docker compatibility** | 100% | 100% | ~90% |

**How to choose:**
- Migrating from Docker or need Docker-in-Docker? Use **docker** or **podman-rootful**
- Security or compliance requirements? Use **podman-rootless** (use Kaniko for image builds)
- Not sure? Start with **docker**

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

### With Rootful Scenarios (Docker / Podman Rootful)

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

## Migrating Between Scenarios

### Between Docker and Podman Rootful

These are functionally identical — just change the source:

```hcl
source = "schubergphilis/mcaf-gitlab-runner-autoscaler/aws//scenarios/podman-rootful"
```

### To/From Podman Rootless

1. Update module source
2. Update CI/CD pipelines (if moving to rootless):
   - Remove Docker-in-Docker jobs
   - Add Kaniko/Buildah for image builds
   - Add `:z` suffix to volume mounts for SELinux compatibility
3. Run `terraform apply`

## Debugging

### View Manager Logs

```bash
# Find ECS task
aws ecs list-tasks --cluster <cluster-name>

# View logs in CloudWatch
aws logs tail /aws/ecs/<cluster-name> --follow
```

### SSH to Runner Instance

Instances run on private subnets with SSH restricted to the manager security group. SSH access uses [EC2 Instance Connect](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/connect-linux-inst-eic.html) with ephemeral keys (no static SSH key). To connect for troubleshooting, add a temporary ingress rule to the instance security group (output: `instance_security_group_id`) for your bastion or VPN, then:

```bash
INSTANCE_ID="i-xxxxxxxxxxxxxxxxx"

# Generate ephemeral key pair
ssh-keygen -t ed25519 -f /tmp/eic_key -N "" -q

# Push public key (valid for 60 seconds)
aws ec2-instance-connect send-ssh-public-key \
  --instance-id "$INSTANCE_ID" \
  --instance-os-user core \
  --ssh-public-key file:///tmp/eic_key.pub

# SSH in (user: root for docker/podman-rootful, core for podman-rootless)
ssh -i /tmp/eic_key -o StrictHostKeyChecking=no core@<instance-private-ip>
```

### Troubleshooting

**Manager not starting jobs:** Check ECS task logs in CloudWatch, verify `gitlab_runner_token` is valid, check security group allows outbound to GitLab URL.

**Instances not scaling:** Check Auto Scaling Group activity, verify IAM permissions, check autoscaler policy.

**Permission denied in rootless jobs:** Adjust volume mount permissions or add `:z` SELinux label. Use ports >= 1024 or configure `net.ipv4.ip_unprivileged_port_start`.

## Support

- **Issues**: [GitHub Issues](https://github.com/schubergphilis-ep/terraform-aws-mcaf-gitlab-runner-autoscaler/issues)
- **Documentation**: See individual scenario READMEs for terraform-docs
