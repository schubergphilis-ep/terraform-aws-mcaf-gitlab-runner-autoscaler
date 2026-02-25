# Ignition Configuration Modules

This directory contains modular Ignition configuration for GitLab Runner instances. The modules are organized to eliminate duplication and conditionals while providing clean, purpose-built configurations for different Podman scenarios.

## Architecture

The Ignition modules are split into three independent modules:

```
modules/ignition/
├── common/              # Shared systemd units (instance store, Docker masking)
│   ├── main.tf
│   ├── outputs.tf
│   └── terraform.tf
├── podman-rootful/      # Rootful Podman configuration
│   ├── main.tf          # Imports common + adds rootful-specific units
│   ├── variables.tf     # Requires ssh_authorized_key
│   ├── outputs.tf
│   └── terraform.tf
├── podman-rootless/     # Rootless Podman configuration
│   ├── main.tf          # Imports common + adds rootless-specific units
│   ├── outputs.tf       # No variables needed!
│   └── terraform.tf
└── README.md            # This file
```

## Benefits of This Structure

1. **Zero Conditionals:** No `count` or ternary operators - each module is purpose-built
2. **Clear Separation:** Common vs. scenario-specific logic is explicit
3. **Type Safety:** Rootless module doesn't even have an `ssh_authorized_key` variable
4. **Reusable:** Common module is shared via composition, not duplication
5. **Easy to Extend:** Add new scenarios by creating a new module that imports `common`

## Modules

### common/

Provides shared systemd units used by all Podman scenarios.

**Units:**
- `setup-instance-store.service` - Conditionally provisions NVMe instance store
- `var-lib-containers.mount` - Mounts instance store to `/var/lib/containers`
- `mask_docker` - Masks Docker service to prevent conflicts

**Outputs:**
- `setup_instance_store_rendered`
- `var_lib_containers_rendered`
- `mask_docker_rendered`

**Usage:**
```hcl
module "common" {
  source = "../../modules/ignition/common"
}
```

### podman-rootful/

Complete Ignition configuration for rootful Podman.

**Use case:** Maximum compatibility, Docker-in-Docker, privileged operations

**Features:**
- **User:** `root` (configured via Ignition)
- **Socket:** `/run/podman/podman.sock` (system-level)
- **Privileged mode:** Supported
- **SSH:** Requires `ssh_authorized_key` for root user

**Systemd Units:**
- Imports all units from `common/`
- `podman.socket` - Rootful Podman socket
- `docker-sock-symlink.service` - Creates `/var/run/docker.sock` → `/run/podman/podman.sock`

**Inputs:**
| Name | Description | Type | Required |
|------|-------------|------|:--------:|
| ssh_authorized_key | SSH public key for root user | `string` | yes |

**Outputs:**
| Name | Description |
|------|-------------|
| rendered | Complete Ignition configuration (JSON) |

**Usage:**
```hcl
module "ignition" {
  source = "../../modules/ignition/podman-rootful"

  ssh_authorized_key = module.manager.public_ssh_key
}

resource "aws_launch_template" "this" {
  # ...
  user_data = base64encode(module.ignition.rendered)
}
```

### podman-rootless/

Complete Ignition configuration for rootless Podman.

**Use case:** Enhanced security, compliance, multi-tenant environments

**Features:**
- **User:** `core` (UID 1000) - SSH handled by AWS key_pair
- **Socket:** `/run/user/1000/podman/podman.sock` (user-level)
- **Privileged mode:** Not supported
- **SSH:** No configuration needed (AWS handles it)

**Systemd Units:**
- Imports all units from `common/`
- `podman.socket` - System-level Podman socket
- `podman-user.service` - Enables rootless Podman for core user
- `docker-sock-symlink.service` - Creates `/var/run/docker.sock` → `/run/user/1000/podman/podman.sock`

**Inputs:**
None! SSH is handled by AWS key_pair in the launch template.

**Outputs:**
| Name | Description |
|------|-------------|
| rendered | Complete Ignition configuration (JSON) |

**Usage:**
```hcl
module "ignition" {
  source = "../../modules/ignition/podman-rootless"
  # No variables needed!
}

resource "aws_launch_template" "this" {
  # ...
  user_data = base64encode(module.ignition.rendered)
}
```

## Usage in Scenarios

### Rootful Scenario

```hcl
# scenarios/podman-rootful/main.tf
module "ignition" {
  source = "../../modules/ignition/podman-rootful"

  ssh_authorized_key = module.manager.public_ssh_key
}

module "instance" {
  source = "../../modules/instance"
  # ...
  user_data = base64encode(module.ignition.rendered)
}
```

### Rootless Scenario

```hcl
# scenarios/podman-rootless/main.tf
module "ignition" {
  source = "../../modules/ignition/podman-rootless"
  # No ssh_authorized_key - AWS key_pair handles it!
}

module "instance" {
  source = "../../modules/instance"
  # ...
  user_data = base64encode(module.ignition.rendered)
}
```

## Creating Custom Scenarios

To create a custom scenario (e.g., "podman-hardened"):

1. **Create new module directory:**
   ```bash
   mkdir modules/ignition/podman-hardened
   ```

2. **Create main.tf:**
   ```hcl
   module "common" {
     source = "../common"
   }

   # Add your custom systemd units here
   data "ignition_systemd_unit" "my_custom_unit" {
     # ...
   }

   data "ignition_config" "this" {
     systemd = [
       module.common.setup_instance_store_rendered,
       module.common.var_lib_containers_rendered,
       module.common.mask_docker_rendered,
       data.ignition_systemd_unit.my_custom_unit.rendered,
     ]
   }
   ```

3. **Add outputs.tf:**
   ```hcl
   output "rendered" {
     value = data.ignition_config.this.rendered
   }
   ```

4. **Add variables.tf** (if needed)

5. **Use it in a scenario:**
   ```hcl
   module "ignition" {
     source = "../../modules/ignition/podman-hardened"
   }
   ```

## Comparison: Old vs New Structure

### Old Structure (With Conditionals)

```hcl
# modules/ignition/rootful.tf
data "ignition_user" "root" {
  count = var.ssh_authorized_key != "" ? 1 : 0  # ❌ Conditional
  # ...
}

data "ignition_config" "rootful" {
  users = var.ssh_authorized_key != "" ? [      # ❌ Conditional
    data.ignition_user.root[0].rendered
  ] : []
}
```

**Issues:**
- Conditionals make code harder to understand
- Both rootful and rootless shared one module
- Rootless had unused `ssh_authorized_key` variable

### New Structure (No Conditionals)

```hcl
# modules/ignition/podman-rootful/main.tf
data "ignition_user" "root" {
  # ✅ No conditionals - always creates root user
  name = "root"
  ssh_authorized_keys = [var.ssh_authorized_key]
}

data "ignition_config" "this" {
  users = [
    data.ignition_user.root.rendered  # ✅ Simple array
  ]
}
```

```hcl
# modules/ignition/podman-rootless/main.tf
data "ignition_config" "this" {
  systemd = [...]
  # ✅ No users block at all - AWS handles SSH
}
```

**Benefits:**
- Zero conditionals
- Each module has exactly what it needs
- Clear intent and purpose

## Troubleshooting

### Module Not Found

**Error:** `Module not found: modules/ignition/podman-rootful`

**Solution:** Ensure you're using the correct path with subdirectory:
```hcl
source = "../../modules/ignition/podman-rootful"  # Correct
source = "../../modules/ignition"                  # Incorrect
```

### SSH Access Not Working

**Rootful:**
```bash
# SSH as root
ssh -i key.pem root@instance-ip

# Check key was configured
cat /root/.ssh/authorized_keys
```

**Rootless:**
```bash
# SSH as core
ssh -i key.pem core@instance-ip

# Check key was configured by AWS
cat /home/core/.ssh/authorized_keys
```

### Common Module Changes Not Applied

If you modify the `common/` module, both dependent modules automatically pick up the changes. Just run `terraform init -upgrade` to refresh.

## Testing

After modifying any module:

1. **Format code:**
   ```bash
   terraform fmt -recursive
   ```

2. **Validate each module:**
   ```bash
   terraform validate modules/ignition/common/
   terraform validate modules/ignition/podman-rootful/
   terraform validate modules/ignition/podman-rootless/
   ```

3. **Test in scenarios:**
   ```bash
   cd scenarios/podman-rootful
   terraform init
   terraform plan

   cd ../podman-rootless
   terraform init
   terraform plan
   ```

## Design Decisions

### Why Separate Modules Instead of One Module with Variables?

**Option A (Old):** One module with `mode` variable
```hcl
module "ignition" {
  source = "../../modules/ignition"
  mode   = "rootful"  # or "rootless"
  ssh_authorized_key = var.key
}
```

**Option B (New):** Separate purpose-built modules
```hcl
module "ignition" {
  source = "../../modules/ignition/podman-rootful"
  ssh_authorized_key = var.key
}
```

**Why we chose Option B:**
- ✅ No conditionals or if/else logic
- ✅ Type-safe (rootless has no ssh_authorized_key variable)
- ✅ Clear what each module does
- ✅ Easy to create new variants
- ✅ Terraform module best practices

### Why Module Composition Over Inheritance?

We use module composition (importing `common`) rather than inheritance:
```hcl
module "common" {
  source = "../common"
}

data "ignition_config" "this" {
  systemd = [
    module.common.setup_instance_store_rendered,  # ← Composition
    # ... scenario-specific units
  ]
}
```

**Benefits:**
- DRY principle: Common units defined once
- Explicit dependencies
- Easy to understand data flow
- Terraform-native pattern

## Performance

- **Ignition runs once** at boot (minimal overhead)
- **Module composition** has zero runtime cost (resolved at plan time)
- **NVMe instance store** provides significant I/O performance boost

## Security

- **Rootful:** Runs with full privileges (trusted environments)
- **Rootless:** User namespace isolation (better for multi-tenant)
- **SSH keys:** Stored securely in Ignition config (encrypted by AWS)
- **Docker masking:** Prevents accidental Docker usage

## Related Documentation

- [Ignition Specification](https://coreos.github.io/ignition/)
- [Fedora CoreOS](https://docs.fedoraproject.org/en-US/fedora-coreos/)
- [Podman Rootless](https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md)
- [Terraform Module Composition](https://www.terraform.io/language/modules/develop/composition)

## Changelog

- **2025-11-10:** Split into separate common/rootful/rootless modules
- **2025-11-10:** Eliminated all conditionals
- **2025-11-10:** Removed ssh_authorized_key from rootless module

## Contributing

When modifying these modules:

1. **Common changes:** Update `common/` module
2. **Scenario-specific:** Update individual scenario modules
3. **Test both scenarios** after changes
4. **Update this README** with any new modules or behaviors

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