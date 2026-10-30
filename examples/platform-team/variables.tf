# Copyright 2026 Appvia Ltd.
# SPDX-License-Identifier: Apache-2.0


variable "resource_group_name" {
  description = "Name of the existing resource group for the ipam storage account."
  type        = string
}

variable "location" {
  description = "Azure region for the storage account."
  type        = string
  default     = "uksouth"
}

variable "storage_account_name" {
  description = "Globally unique name of the ipam storage account."
  type        = string
}

variable "environment_role" {
  description = "How the consuming teams get write access to their reservations documents (builtin or custom)."
  type        = string
  default     = "builtin"
}

variable "team_a_principal_ids" {
  description = "Object IDs of team A's deploy identities. They may allocate only from the team-a pool."
  type        = list(string)
}

variable "team_b_principal_ids" {
  description = "Object IDs of team B's deploy identities. They may allocate only from the team-b pool."
  type        = list(string)
}

variable "tags" {
  description = "Tags applied to the storage account."
  type        = map(string)
  default     = {}
}
