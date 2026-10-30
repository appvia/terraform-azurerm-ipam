# Copyright 2026 Appvia Ltd.
# SPDX-License-Identifier: Apache-2.0


data "azapi_client_config" "current" {}

## Hardened storage account: flat namespace (path conditions are only safe without HNS),
## Entra ID auth only, versioning plus blob and container soft delete.
resource "azapi_resource" "storage_account" {
  #checkov:skip=CKV_AZURE_33:Queue service is not used; only blob storage holds ipam documents
  #checkov:skip=CKV_AZURE_59:Environment pipelines reach the account over the public endpoint; network restrictions are deployment-specific
  #checkov:skip=CKV_AZURE_35:Default network action deny would block environment pipelines; network rules are deployment-specific
  #checkov:skip=CKV_AZURE_43:Name is supplied by the caller and validated by the variable
  type      = "Microsoft.Storage/storageAccounts@2023-05-01"
  name      = var.storage_account_name
  parent_id = "/subscriptions/${local.subscription_id}/resourceGroups/${var.resource_group_name}"
  location  = var.location
  tags      = var.tags

  body = {
    kind = "StorageV2"
    sku  = { name = "Standard_${var.account_replication_type}" }
    properties = {
      allowBlobPublicAccess        = false
      allowCrossTenantReplication  = false
      allowSharedKeyAccess         = false
      defaultToOAuthAuthentication = true
      isHnsEnabled                 = false
      isLocalUserEnabled           = false
      isSftpEnabled                = false
      minimumTlsVersion            = "TLS1_2"
      supportsHttpsTrafficOnly     = true
      encryption = {
        keySource                       = "Microsoft.Storage"
        requireInfrastructureEncryption = true
        services = {
          blob = { enabled = true }
          file = { enabled = true }
        }
      }
    }
  }

  retry = {
    error_message_regex = local.lock_retry_regex
  }

  # The account holds the only record of allocated ranges; losing it allows overlaps.
  lifecycle {
    prevent_destroy = true
  }
}

## Blocks deletion of the account, and (by inheritance) its containers, through ARM.
## Data-plane deletes are not covered; soft delete and versioning protect those.
## The lock also blocks deleting role assignments and the custom role under the account
## (ScopeLocked). So it depends on every grant, and it is replaced whenever the set of
## grants changes: in one apply, Terraform deletes the lock, then deletes or changes the
## grants, then re-creates the lock.
resource "azapi_resource" "lock" {
  type      = "Microsoft.Authorization/locks@2020-05-01"
  name      = "ipam-do-not-delete"
  parent_id = azapi_resource.storage_account.id

  replace_triggers_external_values = {
    platform            = sort(distinct(var.platform_principal_ids))
    readers             = sort(distinct(var.reader_principal_ids))
    environment_readers = sort(keys(local.environment_readers))
    environment_writers = sort(keys(local.environment_writers))
    environment_role    = var.environment_role
  }

  body = {
    properties = {
      level = "CanNotDelete"
      notes = "The account holds the only record of allocated ipam ranges. Remove this lock deliberately before deleting it."
    }
  }

  depends_on = [
    azapi_resource.platform,
    azapi_resource.reader,
    azapi_resource.environment_reader,
    azapi_resource.environment_writer,
    azapi_resource.reservations_writer,
  ]
}

## blobServices/default always exists, so it is updated rather than created.
resource "azapi_update_resource" "blob_service" {
  type        = "Microsoft.Storage/storageAccounts/blobServices@2023-05-01"
  resource_id = "${azapi_resource.storage_account.id}/blobServices/default"

  body = {
    properties = {
      isVersioningEnabled = true
      deleteRetentionPolicy = {
        enabled = true
        days    = var.soft_delete_retention_days
      }
      containerDeleteRetentionPolicy = {
        enabled = true
        days    = var.soft_delete_retention_days
      }
    }
  }
}

resource "azapi_resource" "container" {
  type      = "Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01"
  name      = var.container_name
  parent_id = azapi_update_resource.blob_service.id

  body = {
    properties = {
      publicAccess = "None"
    }
  }

  retry = {
    error_message_regex = concat(["StorageAccountIsNotProvisioned"], local.lock_retry_regex)
  }

  lifecycle {
    prevent_destroy = true
  }
}

## Platform identities: full data access to the container (pools and reservations).
resource "azapi_resource" "platform" {
  for_each = toset(var.platform_principal_ids)

  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = uuidv5("url", "${local.assignment_seed}/platform/${each.value}")
  parent_id = local.container_scope

  body = {
    properties = {
      roleDefinitionId = local.role_definition_ids.contributor
      principalId      = each.value
      description      = "ipam platform identity: manages pools/* and reservations/*"
    }
  }

  retry = { error_message_regex = local.role_retry_regex }
}

## Read-only identities.
resource "azapi_resource" "reader" {
  for_each = toset(var.reader_principal_ids)

  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = uuidv5("url", "${local.assignment_seed}/reader/${each.value}")
  parent_id = local.container_scope

  body = {
    properties = {
      roleDefinitionId = local.role_definition_ids.reader
      principalId      = each.value
      description      = "ipam reader"
    }
  }

  retry = { error_message_regex = local.role_retry_regex }
}

## Every environment identity can read pools/* and reservations/*.
resource "azapi_resource" "environment_reader" {
  for_each = local.environment_readers

  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = uuidv5("url", "${local.assignment_seed}/environment-reader/${each.key}")
  parent_id = local.container_scope

  body = {
    properties = {
      roleDefinitionId = local.role_definition_ids.reader
      principalId      = each.value.principal_id
      description      = "ipam environment ${each.value.environment}: read pools and reservations"
    }
  }

  retry = { error_message_regex = local.role_retry_regex }
}

## Data-actions-only role: blob read and write, no delete, no add, no management plane.
resource "azapi_resource" "reservations_writer" {
  count = local.create_writer_role ? 1 : 0

  type      = "Microsoft.Authorization/roleDefinitions@2022-04-01"
  name      = uuidv5("url", "${local.assignment_seed}/${local.writer_role_name}")
  parent_id = local.container_scope

  body = {
    properties = {
      roleName    = local.writer_role_name
      description = "Overwrite ipam reservations documents in ${var.storage_account_name}/${var.container_name}. Blob read and write only; no delete and no management-plane actions."
      type        = "CustomRole"
      permissions = [{
        actions    = []
        notActions = []
        dataActions = [
          "${local.blob_action_prefix}/read",
          "${local.blob_action_prefix}/write",
        ]
        notDataActions = []
      }]
      assignableScopes = [local.container_scope]
    }
  }

  # Switching to builtin: the writer grants move off this role in the same apply.
  retry = { error_message_regex = ["RoleDefinitionHasAssignments"] }
}

## Conditioned write grant per environment principal; environments with no pools get none.
resource "azapi_resource" "environment_writer" {
  for_each = local.environment_writers

  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"
  name      = uuidv5("url", "${local.assignment_seed}/environment-writer/${each.key}")
  parent_id = local.container_scope

  body = {
    properties = {
      roleDefinitionId = var.environment_role == "custom" ? local.writer_role_definition_id : local.role_definition_ids.contributor
      principalId      = each.value.principal_id
      description      = "ipam environment ${each.value.environment}: overwrite own reservations documents"
      conditionVersion = "2.0"
      condition        = local.environment_conditions[each.value.environment]
    }
  }

  retry = { error_message_regex = local.role_retry_regex }
}
