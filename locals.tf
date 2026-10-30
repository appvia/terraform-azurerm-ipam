
locals {
  blob_endpoint = "https://${var.storage_account_name}.blob.core.windows.net"

  subscription_id = data.azapi_client_config.current.subscription_id
  container_scope = azapi_resource.container.id

  # Seed for deterministic role assignment and definition names; built from inputs only.
  assignment_seed = "${var.storage_account_name}/${var.container_name}"

  # Newly created principals and role definitions can take a while to replicate.
  role_retry_regex = ["PrincipalNotFound", "RoleDefinitionDoesNotExist"]

  # Deleting the lock and then the account races: ARM keeps answering ScopeLocked until
  # the lock removal has propagated.
  lock_retry_regex = ["ScopeLocked", "(?i)locked"]

  role_definition_ids = {
    contributor = "/subscriptions/${local.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe"
    reader      = "/subscriptions/${local.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/2a2b9908-6ea1-4ae2-8e65-a410df84e7d1"
  }

  blob_action_prefix = "Microsoft.Storage/storageAccounts/blobServices/containers/blobs"
  blob_path_attr     = "@Resource[Microsoft.Storage/storageAccounts/blobServices/containers/blobs:path]"

  writer_role_name = "ipam-reservations-writer-${var.storage_account_name}-${var.container_name}"

  # One entry per (environment, principal) for the read grant.
  environment_readers = merge([
    for env_name, env in var.environments : {
      for principal_id in env.principal_ids : "${env_name}/${principal_id}" => {
        environment  = env_name
        principal_id = principal_id
      }
    }
  ]...)

  # Environments with at least one pool get a conditioned write grant; an environment
  # with no pools is read-only.
  environment_writers = merge([
    for env_name, env in var.environments : {
      for principal_id in env.principal_ids : "${env_name}/${principal_id}" => {
        environment  = env_name
        principal_id = principal_id
      }
    } if length(env.pool_ids) > 0
  ]...)

  # "reservations/<pool_id>.json" path test, one StringEquals clause per pool, OR-chained.
  environment_path_tests = {
    for env_name, env in var.environments : env_name => join("\n  OR\n  ", [
      for pool_id in env.pool_ids : "${local.blob_path_attr} StringEquals 'reservations/${pool_id}.json'"
    ]) if length(env.pool_ids) > 0
  }

  # Writes are allowed only on the environment's own reservations documents.
  write_clause = {
    for env_name, path_test in local.environment_path_tests : env_name => <<-EOT
      (
       (
        !(ActionMatches{'${local.blob_action_prefix}/write'})
       )
       OR
       (
        ${path_test}
       )
      )
    EOT
  }

  # Builtin mode only: delete/add/move are guarded by a path test that can never match.
  never_clauses = join("\nAND\n", [
    for action in ["delete", "add/action", "move/action"] : trimspace(<<-EOT
      (
       (
        !(ActionMatches{'${local.blob_action_prefix}/${action}'})
       )
       OR
       (
        ${local.blob_path_attr} StringEquals '__ipam_never__'
       )
      )
    EOT
    )
  ])

  environment_conditions = {
    for env_name, clause in local.write_clause : env_name => (
      var.environment_role == "custom"
      ? trimspace(clause)
      : trimspace("${clause}AND\n${local.never_clauses}")
    )
  }

  create_writer_role = var.environment_role == "custom" && length(local.environment_writers) > 0
}
