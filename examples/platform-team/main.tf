# Copyright 2026 Appvia Ltd.
# SPDX-License-Identifier: Apache-2.0


#####################################################################################
# Terraform module examples are meant to show an _example_ on how to use a module
# per use-case. The code below should not be copied directly but referenced in order
# to build your own root module that invokes this module
#####################################################################################

data "azapi_client_config" "current" {}

locals {
  # Pool ID => the team's carve-out and deploy identities. Pool IDs are lowercase.
  teams = {
    team-a = {
      cidr          = "10.1.0.0/16"
      principal_ids = var.team_a_principal_ids
    }
    team-b = {
      cidr          = "10.2.0.0/16"
      principal_ids = var.team_b_principal_ids
    }
  }
}

## Storage and grants. The identity running this apply is the platform identity.
module "ipam" {
  source = "../../"

  resource_group_name  = var.resource_group_name
  location             = var.location
  storage_account_name = var.storage_account_name
  environment_role     = var.environment_role

  platform_principal_ids = [data.azapi_client_config.current.object_id]

  # Each team may overwrite only reservations/<its pool>.json.
  environments = {
    for pool_id, team in local.teams : pool_id => {
      pool_ids      = [pool_id]
      principal_ids = team.principal_ids
    }
  }

  tags = var.tags
}

## The platform team owns the pool hierarchy.
resource "ipam_pool" "root" {
  id          = "platform"
  cidrs       = ["10.0.0.0/8"]
  description = "All private IPv4 space"

  # The container and the platform grant must exist first.
  depends_on = [module.ipam]
}

## One child pool per consuming team.
resource "ipam_pool" "team" {
  for_each = local.teams

  id          = each.key
  parent_pool = ipam_pool.root.id
  cidr        = each.value.cidr

  labels = {
    owner = each.key
  }

  lifecycle {
    replace_triggered_by = [ipam_pool.root.cidrs]
  }
}
