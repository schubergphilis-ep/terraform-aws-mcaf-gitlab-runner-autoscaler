# Tests for the ignition/podman-rootful module
# No mocking needed — ignition provider uses data sources only

run "defaults" {
  command = plan

  assert {
    condition     = output.rendered != null
    error_message = "rendered output should not be null"
  }

  assert {
    condition     = output.rendered != ""
    error_message = "rendered output should not be empty"
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
    condition     = output.rendered != null
    error_message = "rendered output should not be null when zincati is disabled"
  }

  assert {
    condition     = output.rendered != ""
    error_message = "rendered output should not be empty when zincati is disabled"
  }
}
