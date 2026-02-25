# terraform-aws-mcaf-gitlab-runner-autoscaler

Terraform module for deploying auto-scaling [GitLab Runner](https://docs.gitlab.com/runner/) infrastructure on AWS using the [GitLab Runner Autoscaler](https://docs.gitlab.com/runner/runner_autoscale/gitlab-runner-autoscaler/). Runners are managed by an ECS Fargate task and execute CI/CD jobs on EC2 Spot instances running [Fedora CoreOS](https://docs.fedoraproject.org/en-US/fedora-coreos/) with [Podman](https://podman.io/) as the container runtime.

## Architecture

```
                          ┌────────────────────────────────────────┐
                          │ AWS VPC                                │
                          │                                        │
                          │ ┌────────────────────────────────────┐ │
                          │ │ ECS Fargate (Manager)              │ │
                          │ │                                    │ │
  GitLab ◄── polling ───► │ │  gitlab-runner-autoscaler          │ │
                          │ │  - Polls for pending jobs          │ │
                          │ │  - Scales EC2 instances            │ │
                          │ │  - Connects via SSH                │ │
                          │ └──────────────────┬─────────────────┘ │
                          │                    │ SSH               │
                          │ ┌──────────────────▼─────────────────┐ │
                          │ │ Auto Scaling Group (Executors)     │ │
                          │ │                                    │ │
                          │ │  ┌──────────┐  ┌──────────┐        │ │
                          │ │  │ EC2 Spot │  │ EC2 Spot │ …      │ │
                          │ │  │ Fedora   │  │ Fedora   │        │ │
                          │ │  │ CoreOS   │  │ CoreOS   │        │ │
                          │ │  │ Podman   │  │ Podman   │        │ │
                          │ │  └──────────┘  └──────────┘        │ │
                          │ │                                    │ │
                          │ │  Scales 0 → N based on demand      │ │
                          │ └────────────────────────────────────┘ │
                          │                                        │
                          │ ┌────────────────────────────────────┐ │
                          │ │ AWS Secrets Manager                │ │
                          │ │  - Runner config (TOML as JSON)    │ │
                          │ │  - SSH private key                 │ │
                          │ └────────────────────────────────────┘ │
                          └────────────────────────────────────────┘
```

**Key components:**

- **Manager** (ECS Fargate) — Runs a [custom wrapper image](https://github.com/schubergphilis-ep/gitlab-runner-autoscaler-image) around `gitlab/gitlab-runner` on ARM64. The entrypoint fetches runner configuration and SSH keys from Secrets Manager, configures Docker credential helpers, and launches the runner. Polls GitLab for jobs, provisions EC2 instances via an Auto Scaling Group, and connects to them over SSH. See the [GitLab Runner Autoscaler documentation](https://docs.gitlab.com/runner/runner_autoscale/gitlab-runner-autoscaler/) for details on how autoscaling works.
- **Executors** (EC2 Spot) — Fedora CoreOS instances with Podman. Automatically discovered compute-optimized instance types with NVMe instance storage. Scale to zero when idle.
- **Secrets Manager** — Stores the runner configuration (including the GitLab token) and the SSH private key used for manager-to-executor communication.

### Manager Image

The manager runs a [custom wrapper image](https://github.com/schubergphilis-ep/gitlab-runner-autoscaler-image) that extends `gitlab/gitlab-runner:alpine` with AWS tooling (aws-cli, fleeting-plugin-aws, docker-credential-ecr-login). Its entrypoint handles fetching secrets from AWS Secrets Manager and transforming the runner configuration from JSON to TOML at startup.

You can use a custom image by setting `gitlab_runner_image`. Your image must implement the same entrypoint contract (reading `GITLAB_CONFIG_SECRET_NAME`, `SSH_KEY_SECRET_NAME`, and optionally `DOCKER_CREDENTIAL_HELPERS` environment variables). See the [image repository](https://github.com/schubergphilis-ep/gitlab-runner-autoscaler-image) for the full entrypoint specification.

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

## Terraform Documentation

For detailed inputs, outputs, resources, and requirements, see the documentation for each submodule:

### Scenarios

| Scenario | Documentation |
|----------|---------------|
| docker | [scenarios/docker/README.md](./scenarios/docker/README.md) |
| podman-rootful | [scenarios/podman-rootful/README.md](./scenarios/podman-rootful/README.md) |
| podman-rootless | [scenarios/podman-rootless/README.md](./scenarios/podman-rootless/README.md) |

### Modules

| Module | Documentation |
|--------|---------------|
| manager | [modules/manager/README.md](./modules/manager/README.md) |
| instance | [modules/instance/README.md](./modules/instance/README.md) |
| ignition | [modules/ignition/README.md](./modules/ignition/README.md) |

### Docker Credential Helpers

To authenticate with private container registries, configure credential helpers:

```hcl
module "gitlab_runner" {
  source = "schubergphilis/mcaf-gitlab-runner-autoscaler/aws//scenarios/docker"

  # ...

  docker_credential_helpers = {
    "123456789012.dkr.ecr.eu-west-1.amazonaws.com" = "ecr-login"
    "gcr.io"                                        = "gcloud"
  }
}
```

This writes the map as `credHelpers` in the manager's `/root/.docker/config.json`.

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

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->