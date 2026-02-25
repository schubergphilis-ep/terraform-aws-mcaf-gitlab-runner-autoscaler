# terraform-aws-mcaf-gitlab-runner-autoscaler

Terraform module for deploying auto-scaling [GitLab Runner](https://docs.gitlab.com/runner/) infrastructure on AWS. Runners are managed by an ECS Fargate task and execute CI/CD jobs on EC2 Spot instances running [Fedora CoreOS](https://docs.fedoraproject.org/en-US/fedora-coreos/) with [Podman](https://podman.io/) as the container runtime.

## Architecture

```
                          ┌──────────────────────────────────┐
                          │          AWS VPC                  │
                          │                                    │
                          │  ┌──────────────────────────────┐ │
                          │  │ ECS Fargate (Manager)         │ │
                          │  │                                │ │
  GitLab ◄── polling ───► │  │  gitlab-runner-autoscaler     │ │
                          │  │  - Polls for pending jobs      │ │
                          │  │  - Scales EC2 instances        │ │
                          │  │  - Connects via SSH             │ │
                          │  └──────────────┬─────────────────┘ │
                          │                 │ SSH                 │
                          │  ┌──────────────▼─────────────────┐ │
                          │  │ Auto Scaling Group (Executors)  │ │
                          │  │                                  │ │
                          │  │  ┌──────────┐  ┌──────────┐    │ │
                          │  │  │ EC2 Spot │  │ EC2 Spot │ …  │ │
                          │  │  │ Fedora   │  │ Fedora   │    │ │
                          │  │  │ CoreOS   │  │ CoreOS   │    │ │
                          │  │  │ Podman   │  │ Podman   │    │ │
                          │  │  └──────────┘  └──────────┘    │ │
                          │  │                                  │ │
                          │  │  Scales 0 → N based on demand   │ │
                          │  └──────────────────────────────────┘ │
                          │                                        │
                          │  ┌──────────────────────────────────┐ │
                          │  │ AWS Secrets Manager               │ │
                          │  │  - Runner config (TOML as JSON)   │ │
                          │  │  - SSH private key                 │ │
                          │  └──────────────────────────────────┘ │
                          └────────────────────────────────────────┘
```

**Key components:**

- **Manager** (ECS Fargate) — Runs the `gitlab-runner-autoscaler` container on ARM64. Polls GitLab for jobs, provisions EC2 instances via an Auto Scaling Group, and connects to them over SSH.
- **Executors** (EC2 Spot) — Fedora CoreOS instances with Podman. Automatically discovered compute-optimized instance types with NVMe instance storage. Scale to zero when idle.
- **Secrets Manager** — Stores the runner configuration (including the GitLab token) and the SSH private key used for manager-to-executor communication.

## Quick Start

Pick a [scenario](#scenarios), provide your GitLab token and VPC details, and apply:

```hcl
module "gitlab_runner" {
  source = "schubergphilis/mcaf-gitlab-runner-autoscaler/aws//scenarios/docker"

  runner_name         = "my-runner"
  gitlab_url          = "https://gitlab.com"
  gitlab_runner_token = var.gitlab_runner_token

  vpc_id         = var.vpc_id
  vpc_subnet_ids = var.vpc_subnet_ids

  tags = {
    Environment = "production"
  }
}
```

```bash
terraform init
terraform plan
terraform apply
```

## Scenarios

Scenarios are pre-configured, ready-to-use Terraform modules that wrap the base `manager`, `instance`, and `ignition` modules with opinionated defaults. All scenarios use Podman as the container runtime.

| Scenario | Use Case | Privileged | DinD | User | Socket |
|----------|----------|:----------:|:----:|------|--------|
| **[docker](./scenarios/docker/)** | Docker migrations, maximum compatibility | Yes | Yes | `root` | `/var/run/docker.sock` (symlink) |
| **[podman-rootful](./scenarios/podman-rootful/)** | Native Podman, DinD workflows | Yes | Yes | `root` | `/run/podman/podman.sock` |
| **[podman-rootless](./scenarios/podman-rootless/)** | Security-sensitive, compliance | No | No | `core` | `/run/user/1000/podman/podman.sock` |

**How to choose:**

- Migrating from Docker or need Docker-in-Docker? Use **docker** or **podman-rootful**.
- Security or compliance requirements? Use **podman-rootless** (use [Kaniko](https://github.com/GoogleContainerTools/kaniko) for image builds).
- Not sure? Start with **docker** — it's a drop-in replacement for Docker-based runners.

See the [scenarios README](./scenarios/README.md) for detailed comparisons, autoscaling policy examples, and migration guides.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.10.0 |
| aws | ~> 6.0 |
| ignition | ~> 2.1 |

## Inputs

All scenarios share these common variables:

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `runner_name` | Name prefix for the GitLab Runner and all AWS resources | `string` | — | yes |
| `gitlab_url` | GitLab instance URL | `string` | — | yes |
| `gitlab_runner_token` | GitLab Runner authentication token | `string` | — | yes |
| `vpc_id` | VPC ID where infrastructure will be deployed | `string` | — | yes |
| `vpc_subnet_ids` | List of subnet IDs for the manager and executor instances | `list(string)` | — | yes |
| `architecture` | CPU architecture for executor instances (`arm64` or `x86_64`) | `string` | `"arm64"` | no |
| `concurrent_jobs` | Maximum number of concurrent jobs | `number` | `4` | no |
| `capacity_per_instance` | Number of jobs each instance handles concurrently | `number` | `1` | no |
| `max_instances` | Maximum number of EC2 executor instances | `number` | `5` | no |
| `instance_types` | EC2 instance types (auto-discovered if not set) | `list(string)` | `null` | no |
| `privileged_mode` | Enable Docker privileged mode (docker/podman-rootful only) | `bool` | `true` | no |
| `autoscaler_policy` | Autoscaler idle policy configuration | `list(object)` | Scale to zero after 5m | no |
| `kms_key_id` | KMS key ID for Secrets Manager encryption | `string` | `null` | no |
| `os_auto_updates` | Fedora CoreOS auto-update (Zincati) configuration | `object` | Immediate updates enabled | no |
| `tags` | Tags applied to all resources | `map(string)` | `{}` | no |

See individual scenario READMEs for the full variable reference.

## Outputs

| Name | Description |
|------|-------------|
| `manager_security_group_id` | Security group ID of the ECS Fargate manager |
| `instance_security_group_id` | Security group ID of the EC2 executor instances |
| `public_ssh_key` | Public SSH key for accessing runner instances |

## Cost Optimization

The module is designed for minimal cost:

- **EC2 Spot Instances** — Up to 90% savings vs. On-Demand. Uses `price-capacity-optimized` allocation strategy across multiple instance types.
- **ARM64 by default** — ~20% cheaper than x86_64 for equivalent performance.
- **Scale to zero** — No executor instances running when there are no jobs.
- **Auto-discovery** — Automatically selects current-generation compute-optimized instances (C/M families) with NVMe instance storage.

## Module Structure

```
.
├── scenarios/                    # Ready-to-use scenario modules (start here)
│   ├── docker/                   # Podman with Docker API compatibility
│   ├── podman-rootful/           # Rootful Podman
│   └── podman-rootless/          # Rootless Podman (enhanced security)
└── modules/                      # Base modules (used by scenarios)
    ├── manager/                  # ECS Fargate manager, Secrets Manager, IAM
    ├── instance/                 # ASG, launch template, security groups
    └── ignition/                 # Fedora CoreOS Ignition configuration
        ├── common/               # Shared systemd units
        ├── podman-rootful/       # Rootful Podman units
        └── podman-rootless/      # Rootless Podman units
```

Most users should use a **scenario module** directly. The base modules under `modules/` are building blocks for creating custom scenarios — see the [ignition README](./modules/ignition/README.md) for details.

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md).

## License

See [LICENSE](./LICENSE).
