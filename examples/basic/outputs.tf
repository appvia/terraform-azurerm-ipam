# Copyright 2026 Appvia Ltd.
# SPDX-License-Identifier: Apache-2.0


output "backend_url" {
  description = "ipam backend URL for the CLI and IPAM_BACKEND."
  value       = module.ipam.backend_url
}

output "provider_config" {
  description = "Value for provider \"ipam\" { azure_blob = ... }."
  value       = module.ipam.provider_config
}
