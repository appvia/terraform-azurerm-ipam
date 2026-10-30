# Copyright 2026 Appvia Ltd.
# SPDX-License-Identifier: Apache-2.0


#####################################################################################
# Terraform module examples are meant to show an _example_ on how to use a module
# per use-case. The code below should not be copied directly but referenced in order
# to build your own root module that invokes this module
#####################################################################################

## Reading the pool needs only the read grant every team gets.
data "ipam_pool" "team" {
  id = var.pool_id
}

## Each allocation overwrites reservations/<pool_id>.json, which this team may write
## only for its own pool.
resource "ipam_allocation" "subnet" {
  for_each = var.subnets

  pool          = data.ipam_pool.team.id
  prefix_length = each.value
  description   = "${each.key} subnet"

  labels = {
    subnet = each.key
  }
}
