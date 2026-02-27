# Ignition Configuration Modules

Modular Ignition configurations for GitLab Runner instances on Fedora CoreOS. Each scenario gets a purpose-built module with zero conditionals — common logic is shared via composition.

## Architecture

```
modules/ignition/
├── common/              # Shared systemd units and EC2 Instance Connect
├── podman-rootful/      # Rootful Podman configuration
├── podman-rootless/     # Rootless Podman configuration
└── README.md
```

## Modules

### common/

Shared systemd units used by all scenarios. See `common/outputs.tf` for the full list of rendered resources available for composition.

### podman-rootful/

Complete Ignition configuration for rootful Podman.

**Use case:** Maximum compatibility, Docker-in-Docker, privileged operations

- **Socket:** `/run/podman/podman.sock` (system-level)
- **Privileged mode:** Supported

### podman-rootless/

Complete Ignition configuration for rootless Podman.

**Use case:** Enhanced security, compliance, multi-tenant environments

- **User:** `core` (UID 1000)
- **Socket:** `/run/user/1000/podman/podman.sock` (user-level)
- **Privileged mode:** Not supported

## Contributing

When modifying these modules:

1. **Common changes:** Update `common/` module — both scenario modules automatically pick up changes
2. **Scenario-specific:** Update individual scenario modules
3. **Test all scenarios** after changes

### Creating Custom Scenarios

To create a new scenario (e.g., "podman-hardened"):

1. Create `modules/ignition/podman-hardened/`
2. Import the `common` module and add your custom systemd units
3. Expose a single `rendered` output with the complete Ignition config
4. Use it in a scenario via `source = "../../modules/ignition/podman-hardened"`

See `podman-rootful/main.tf` or `podman-rootless/main.tf` for examples.

<!-- BEGIN_TF_DOCS -->
## Requirements

No requirements.

## Providers

No providers.

## Modules

No modules.

## Resources

No resources.

## Inputs

No inputs.

## Outputs

No outputs.
<!-- END_TF_DOCS -->
