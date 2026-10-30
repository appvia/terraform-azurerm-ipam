
variable "resource_group_name" {
  description = "Name of the existing resource group that holds the storage account."
  type        = string
}

variable "location" {
  description = "Azure region for the storage account."
  type        = string
}

variable "storage_account_name" {
  description = "Globally unique name of the storage account that holds the ipam documents (3-24 lowercase letters and digits)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "storage_account_name must be 3-24 lowercase letters or digits."
  }
}

variable "account_replication_type" {
  description = "Replication type of the storage account (for example LRS, ZRS, GRS, GZRS)."
  type        = string
  default     = "GZRS"
}

variable "container_name" {
  description = "Name of the private blob container that holds pools/ and reservations/."
  type        = string
  default     = "ipam"

  validation {
    condition     = can(regex("^[a-z0-9](-?[a-z0-9])*$", var.container_name)) && length(var.container_name) >= 3 && length(var.container_name) <= 63
    error_message = "container_name must be 3-63 lowercase letters, digits or single hyphens, starting and ending with a letter or digit."
  }
}

variable "environment_role" {
  description = <<-EOT
    How environment identities get write access to their reservations documents.
    "builtin" (default): the built-in "Storage Blob Data Contributor" role with a condition limiting writes to the environment's reservations/<pool_id>.json paths and denying blob delete/add/move. This role also carries management-plane actions (containers/delete, containers/write) that conditions cannot restrict; the account's CanNotDelete lock blocks container deletion through ARM, and container soft delete covers the rest.
    "custom": a module-created custom role with only blob read/write data actions, conditioned to the same paths. No delete, no add, no management-plane actions.
  EOT
  type        = string
  default     = "builtin"

  validation {
    condition     = contains(["custom", "builtin"], var.environment_role)
    error_message = "environment_role must be \"custom\" or \"builtin\"."
  }
}

variable "platform_principal_ids" {
  description = "Object IDs of the platform identities. They get \"Storage Blob Data Contributor\" on the container and are the only identities that can write pools/* or delete documents."
  type        = list(string)
  default     = []
}

variable "environments" {
  description = "Per-environment access. Each entry lists the pool IDs whose reservations/<pool_id>.json the environment may overwrite, and the object IDs of its deploy identities. Pool IDs are enough; the pools need not exist yet."
  type = map(object({
    pool_ids      = list(string)
    principal_ids = list(string)
  }))
  default = {}

  validation {
    condition = alltrue(flatten([
      for env in values(var.environments) : [
        for pool_id in env.pool_ids : can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", pool_id))
      ]
    ]))
    error_message = "Every pool ID must match ^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$ (lowercase letters, digits and hyphens, 1-63 characters)."
  }
}

variable "reader_principal_ids" {
  description = "Object IDs of identities that only need to read pools and reservations."
  type        = list(string)
  default     = []
}

variable "soft_delete_retention_days" {
  description = "Retention in days for blob and container soft delete."
  type        = number
  default     = 30

  validation {
    condition     = var.soft_delete_retention_days >= 1 && var.soft_delete_retention_days <= 365
    error_message = "soft_delete_retention_days must be between 1 and 365."
  }
}

variable "tags" {
  description = "Tags applied to the storage account."
  type        = map(string)
  default     = {}
}
