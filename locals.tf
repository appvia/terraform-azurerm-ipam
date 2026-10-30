
locals {
  blob_endpoint = "https://${var.storage_account_name}.blob.core.windows.net"

  # Built from the account ID and the input container name so it does not depend on
  # the container resource's (deprecated) resource_manager_id attribute.
  container_scope = "${azurerm_storage_account.this.id}/blobServices/default/containers/${var.container_name}"

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
