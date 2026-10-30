
## Hardened storage account: flat namespace (path conditions are only safe without HNS),
## Entra ID auth only, versioning plus blob and container soft delete.
resource "azurerm_storage_account" "this" {
  #checkov:skip=CKV_AZURE_33:Queue service is not used; only blob storage holds ipam documents
  #checkov:skip=CKV_AZURE_59:Environment pipelines reach the account over the public endpoint; network restrictions are deployment-specific
  #checkov:skip=CKV_AZURE_35:Default network action deny would block environment pipelines; network rules are deployment-specific
  #checkov:skip=CKV_AZURE_43:Name is supplied by the caller and validated by the variable
  name                              = var.storage_account_name
  resource_group_name               = var.resource_group_name
  location                          = var.location
  account_kind                      = "StorageV2"
  account_tier                      = "Standard"
  account_replication_type          = var.account_replication_type
  allow_nested_items_to_be_public   = false
  cross_tenant_replication_enabled  = false
  default_to_oauth_authentication   = true
  https_traffic_only_enabled        = true
  infrastructure_encryption_enabled = true
  is_hns_enabled                    = false
  local_user_enabled                = false
  min_tls_version                   = "TLS1_2"
  sftp_enabled                      = false
  shared_access_key_enabled         = false
  tags                              = var.tags

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = var.soft_delete_retention_days
    }

    container_delete_retention_policy {
      days = var.soft_delete_retention_days
    }
  }

  # The account holds the only record of allocated ranges; losing it allows overlaps.
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_container" "this" {
  name                  = var.container_name
  storage_account_id    = azurerm_storage_account.this.id
  container_access_type = "private"

  lifecycle {
    prevent_destroy = true
  }
}

## Platform identities: full data access to the container (pools and reservations).
resource "azurerm_role_assignment" "platform" {
  for_each = toset(var.platform_principal_ids)

  scope                = local.container_scope
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = each.value
  description          = "ipam platform identity: manages pools/* and reservations/*"

  depends_on = [azurerm_storage_container.this]
}

## Read-only identities.
resource "azurerm_role_assignment" "reader" {
  for_each = toset(var.reader_principal_ids)

  scope                = local.container_scope
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = each.value
  description          = "ipam reader"

  depends_on = [azurerm_storage_container.this]
}

## Every environment identity can read pools/* and reservations/*.
resource "azurerm_role_assignment" "environment_reader" {
  for_each = local.environment_readers

  scope                = local.container_scope
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = each.value.principal_id
  description          = "ipam environment ${each.value.environment}: read pools and reservations"

  depends_on = [azurerm_storage_container.this]
}

## Data-actions-only role: blob read and write, no delete, no add, no management plane.
resource "azurerm_role_definition" "reservations_writer" {
  count = local.create_writer_role ? 1 : 0

  name              = local.writer_role_name
  scope             = local.container_scope
  description       = "Overwrite ipam reservations documents in ${var.storage_account_name}/${var.container_name}. Blob read and write only; no delete and no management-plane actions."
  assignable_scopes = [local.container_scope]

  permissions {
    actions     = []
    not_actions = []
    data_actions = [
      "${local.blob_action_prefix}/read",
      "${local.blob_action_prefix}/write",
    ]
    not_data_actions = []
  }

  depends_on = [azurerm_storage_container.this]
}

## Conditioned write grant per environment principal; environments with no pools get none.
resource "azurerm_role_assignment" "environment_writer" {
  for_each = local.environment_writers

  scope                = local.container_scope
  role_definition_id   = var.environment_role == "custom" ? azurerm_role_definition.reservations_writer[0].role_definition_resource_id : null
  role_definition_name = var.environment_role == "builtin" ? "Storage Blob Data Contributor" : null
  principal_id         = each.value.principal_id
  description          = "ipam environment ${each.value.environment}: overwrite own reservations documents"
  condition_version    = "2.0"
  condition            = local.environment_conditions[each.value.environment]

  depends_on = [azurerm_storage_container.this]
}
