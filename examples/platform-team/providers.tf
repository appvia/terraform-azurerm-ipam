# Copyright 2026 Appvia Ltd.
# SPDX-License-Identifier: Apache-2.0


provider "azapi" {}

## Authenticates as the platform identity (ARM_* variables or az login), like azapi.
provider "ipam" {
  azure_blob = module.ipam.provider_config

  # The platform grant is created in the same apply; wait for it to take effect.
  access_propagation_timeout = "10m"
}
