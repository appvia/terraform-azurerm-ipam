# Copyright 2026 Appvia Ltd.
# SPDX-License-Identifier: Apache-2.0


variable "account_url" {
  description = "Blob endpoint of the ipam storage account (provider_config.account_url from the platform team)."
  type        = string
}

variable "container" {
  description = "Name of the ipam container (provider_config.container from the platform team)."
  type        = string
  default     = "ipam"
}

variable "pool_id" {
  description = "ID of the pool this team allocates from."
  type        = string
}

variable "subnets" {
  description = "Subnet name => prefix length to allocate from the pool."
  type        = map(number)
  default = {
    app  = 24
    data = 26
  }
}

variable "access_propagation_timeout" {
  description = "How long writes retry access denied while new role assignments take effect."
  type        = string
  default     = "5m"
}
