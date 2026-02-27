# Ignition Modules — Design Decisions

## Why Separate Modules Instead of One Module with Variables?

**Option A:** One module with `mode` variable
```hcl
module "ignition" {
  source = "../../modules/ignition"
  mode   = "rootful"  # or "rootless"
  ssh_authorized_key = var.key
}
```

**Option B (chosen):** Separate purpose-built modules
```hcl
module "ignition" {
  source = "../../modules/ignition/podman-rootful"
}
```

**Why Option B:**
- Zero conditionals or if/else logic
- Type-safe (rootless has no ssh_authorized_key variable)
- Clear what each module does
- Easy to create new variants
- Follows Terraform module best practices

## Why Module Composition Over Inheritance?

We use module composition (importing `common`) rather than inheritance:

```hcl
module "common" {
  source = "../common"
}

data "ignition_config" "this" {
  systemd = [
    module.common.setup_instance_store_rendered,  # Composition
    # ... scenario-specific units
  ]
}
```

**Benefits:**
- DRY principle: Common units defined once
- Explicit dependencies
- Easy to understand data flow
- Terraform-native pattern
