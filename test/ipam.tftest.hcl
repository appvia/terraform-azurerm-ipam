# Plan-only unit tests with a mocked azapi provider: no Azure credentials, no spend.

mock_provider "azapi" {}

variables {
  resource_group_name  = "rg-ipam"
  location             = "uksouth"
  storage_account_name = "ipamtest"
  platform_principal_ids = [
    "00000000-0000-0000-0000-00000000aaaa",
  ]
  reader_principal_ids = [
    "00000000-0000-0000-0000-00000000cccc",
  ]
  environments = {
    prod = {
      pool_ids      = ["uks-prod", "ukw-prod"]
      principal_ids = ["00000000-0000-0000-0000-000000000001"]
    }
  }
}

run "storage_is_hardened" {
  command = plan

  assert {
    condition     = azapi_resource.storage_account.body.properties.isHnsEnabled == false
    error_message = "Hierarchical namespace must be off: blob path conditions are unsafe with HNS."
  }

  assert {
    condition     = azapi_update_resource.blob_service.body.properties.isVersioningEnabled == true
    error_message = "Blob versioning must be on."
  }

  assert {
    condition     = azapi_resource.storage_account.body.properties.allowSharedKeyAccess == false
    error_message = "Shared key access must be off."
  }

  assert {
    condition     = azapi_resource.storage_account.body.properties.minimumTlsVersion == "TLS1_2" && azapi_resource.storage_account.body.properties.allowBlobPublicAccess == false
    error_message = "TLS 1.2 minimum and no public blob access are required."
  }

  assert {
    condition = (
      azapi_update_resource.blob_service.body.properties.deleteRetentionPolicy.days == 30 &&
      azapi_update_resource.blob_service.body.properties.containerDeleteRetentionPolicy.days == 30
    )
    error_message = "Blob and container soft delete must use soft_delete_retention_days (default 30)."
  }

  assert {
    condition     = azapi_resource.container.name == "ipam" && azapi_resource.container.body.properties.publicAccess == "None"
    error_message = "The container must be private and named by container_name."
  }

  assert {
    condition = (
      azapi_resource.lock.body.properties.level == "CanNotDelete" &&
      azapi_resource.lock.name == "ipam-do-not-delete"
    )
    error_message = "The storage account must carry a CanNotDelete lock."
  }

  assert {
    condition = (
      length(azapi_resource.platform) == 1 &&
      endswith(azapi_resource.platform["00000000-0000-0000-0000-00000000aaaa"].body.properties.roleDefinitionId, "/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe")
    )
    error_message = "Platform identities get Storage Blob Data Contributor."
  }

  assert {
    condition = (
      length(azapi_resource.reader) == 1 &&
      endswith(azapi_resource.reader["00000000-0000-0000-0000-00000000cccc"].body.properties.roleDefinitionId, "/roleDefinitions/2a2b9908-6ea1-4ae2-8e65-a410df84e7d1")
    )
    error_message = "Reader identities get Storage Blob Data Reader."
  }

  assert {
    condition     = length(azapi_resource.reservations_writer) == 0
    error_message = "The default (builtin) mode must not create a role definition."
  }
}

run "prod_condition_matches_golden" {
  command = plan

  variables {
    environment_role = "custom"
  }

  override_resource {
    target          = azapi_resource.reservations_writer
    override_during = plan
    values = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/11111111-1111-1111-1111-111111111111"
    }
  }

  assert {
    condition     = azapi_resource.environment_writer["prod/00000000-0000-0000-0000-000000000001"].body.properties.condition == chomp(file("${path.module}/test/testdata/prod_condition.txt"))
    error_message = "The prod write condition must equal test/testdata/prod_condition.txt exactly."
  }

  assert {
    condition = alltrue([
      for pool_id in ["uks-prod", "ukw-prod"] :
      strcontains(azapi_resource.environment_writer["prod/00000000-0000-0000-0000-000000000001"].body.properties.condition, "StringEquals 'reservations/${pool_id}.json'")
    ])
    error_message = "The prod condition must allow both prod reservations paths."
  }

  assert {
    condition     = azapi_resource.environment_writer["prod/00000000-0000-0000-0000-000000000001"].body.properties.conditionVersion == "2.0"
    error_message = "Conditions must use condition_version 2.0."
  }

  assert {
    condition     = azapi_resource.environment_writer["prod/00000000-0000-0000-0000-000000000001"].body.properties.roleDefinitionId == "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/11111111-1111-1111-1111-111111111111"
    error_message = "In custom mode the environment write grant must use the custom role, not a built-in role."
  }

  assert {
    condition     = endswith(azapi_resource.environment_reader["prod/00000000-0000-0000-0000-000000000001"].body.properties.roleDefinitionId, "/roleDefinitions/2a2b9908-6ea1-4ae2-8e65-a410df84e7d1")
    error_message = "Environment identities get Storage Blob Data Reader."
  }
}

run "custom_role_has_only_blob_read_write" {
  command = plan

  variables {
    environment_role = "custom"
  }

  assert {
    condition     = length(azapi_resource.reservations_writer) == 1
    error_message = "Custom mode creates exactly one role definition."
  }

  assert {
    condition     = azapi_resource.reservations_writer[0].body.properties.roleName == "ipam-reservations-writer-ipamtest-ipam"
    error_message = "The custom role name must be ipam-reservations-writer-<account>-<container>."
  }

  assert {
    condition     = length(azapi_resource.reservations_writer[0].body.properties.permissions[0].actions) == 0 && length(azapi_resource.reservations_writer[0].body.properties.permissions[0].notActions) == 0
    error_message = "The custom role must have no management-plane actions."
  }

  assert {
    condition = toset(azapi_resource.reservations_writer[0].body.properties.permissions[0].dataActions) == toset([
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write",
    ])
    error_message = "The custom role data_actions must be exactly blob read and blob write."
  }

  assert {
    condition = alltrue([
      for action in azapi_resource.reservations_writer[0].body.properties.permissions[0].dataActions :
      !strcontains(action, "delete") && !strcontains(action, "add/action") && !strcontains(action, "move/action")
    ])
    error_message = "The custom role must not grant delete, add or move."
  }
}

run "builtin_mode_uses_contributor_with_never_clauses" {
  command = plan

  variables {
    environment_role = "builtin"
  }

  assert {
    condition     = length(azapi_resource.reservations_writer) == 0
    error_message = "Builtin mode must not create a role definition."
  }

  assert {
    condition     = endswith(azapi_resource.environment_writer["prod/00000000-0000-0000-0000-000000000001"].body.properties.roleDefinitionId, "/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe")
    error_message = "Builtin mode assigns Storage Blob Data Contributor to environments."
  }

  assert {
    condition     = azapi_resource.environment_writer["prod/00000000-0000-0000-0000-000000000001"].body.properties.condition == chomp(file("${path.module}/test/testdata/prod_condition_builtin.txt"))
    error_message = "The builtin prod condition must equal test/testdata/prod_condition_builtin.txt exactly."
  }
}

run "invalid_environment_role_fails" {
  command = plan

  variables {
    environment_role = "other"
  }

  expect_failures = [var.environment_role]
}

run "environment_without_pools_gets_no_write" {
  command = plan

  variables {
    environments = {
      prod = {
        pool_ids      = ["uks-prod"]
        principal_ids = ["00000000-0000-0000-0000-000000000001"]
      }
      audit = {
        pool_ids      = []
        principal_ids = ["00000000-0000-0000-0000-000000000002"]
      }
    }
  }

  assert {
    condition     = !contains(keys(azapi_resource.environment_writer), "audit/00000000-0000-0000-0000-000000000002")
    error_message = "An environment with no pools must not get a write assignment."
  }

  assert {
    condition     = contains(keys(azapi_resource.environment_reader), "audit/00000000-0000-0000-0000-000000000002")
    error_message = "An environment with no pools still gets read access."
  }

  assert {
    condition     = keys(azapi_resource.environment_writer) == ["prod/00000000-0000-0000-0000-000000000001"]
    error_message = "Only the environment with pools gets a write assignment."
  }
}

run "invalid_pool_id_fails" {
  command = plan

  variables {
    environments = {
      prod = {
        pool_ids      = ["UKS_Prod"]
        principal_ids = ["00000000-0000-0000-0000-000000000001"]
      }
    }
  }

  expect_failures = [var.environments]
}

run "outputs_known_at_plan" {
  command = plan

  assert {
    condition     = output.backend_url == "azblob://ipamtest.blob.core.windows.net/ipam/"
    error_message = "backend_url must be known at plan time and equal the literal URL."
  }

  assert {
    condition = output.provider_config == {
      account_url = "https://ipamtest.blob.core.windows.net"
      container   = "ipam"
    }
    error_message = "provider_config must be known at plan time and equal the literal object."
  }
}
