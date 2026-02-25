# Tests for the ignition/common module
# No mocking needed — ignition provider uses data sources only

run "defaults" {
  command = plan

  assert {
    condition     = output.setup_instance_store_rendered != null
    error_message = "setup_instance_store_rendered should not be null"
  }

  assert {
    condition     = output.container_storage_mount_rendered != null
    error_message = "container_storage_mount_rendered should not be null"
  }

  assert {
    condition     = output.relabel_container_storage_rendered != null
    error_message = "relabel_container_storage_rendered should not be null"
  }

  assert {
    condition     = output.mask_docker_rendered != null
    error_message = "mask_docker_rendered should not be null"
  }

  assert {
    condition     = output.mask_zincati_rendered == null
    error_message = "mask_zincati_rendered should be null when zincati is enabled (default)"
  }

  assert {
    condition     = output.zincati_config_rendered == null
    error_message = "zincati_config_rendered should be null with immediate strategy (default)"
  }
}

run "custom_storage_path" {
  command = plan

  variables {
    container_storage_path = "/var/home/core/.local/share/containers"
  }

  assert {
    condition     = output.container_storage_mount_rendered != null
    error_message = "container_storage_mount_rendered should not be null with custom path"
  }

  assert {
    condition     = strcontains(output.container_storage_mount_rendered, "var-home-core-.local-share-containers.mount")
    error_message = "mount unit name should reflect the custom storage path"
  }
}

run "zincati_disabled" {
  command = plan

  variables {
    os_auto_updates = {
      enabled = false
    }
  }

  assert {
    condition     = output.mask_zincati_rendered != null
    error_message = "mask_zincati_rendered should not be null when zincati is disabled"
  }

  assert {
    condition     = output.zincati_config_rendered == null
    error_message = "zincati_config_rendered should be null when zincati is disabled"
  }
}

run "zincati_periodic" {
  command = plan

  variables {
    os_auto_updates = {
      strategy = "periodic"
      maintenance_windows = [
        {
          days           = ["Mon", "Tue"]
          start_time     = "22:00"
          length_minutes = 60
        }
      ]
    }
  }

  assert {
    condition     = output.zincati_config_rendered != null
    error_message = "zincati_config_rendered should not be null with periodic strategy"
  }

  assert {
    condition     = output.mask_zincati_rendered == null
    error_message = "mask_zincati_rendered should be null when zincati is enabled"
  }
}

run "invalid_strategy" {
  command = plan

  variables {
    os_auto_updates = {
      strategy = "invalid"
    }
  }

  expect_failures = [
    var.os_auto_updates,
  ]
}

run "periodic_without_windows" {
  command = plan

  variables {
    os_auto_updates = {
      strategy = "periodic"
    }
  }

  expect_failures = [
    var.os_auto_updates,
  ]
}
