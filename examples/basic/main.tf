#####################################################################################
# Terraform module examples are meant to show an _example_ on how to use a module
# per use-case. The code below should not be copied directly but referenced in order
# to build your own root module that invokes this module
#####################################################################################

data "azapi_client_config" "current" {}

resource "azapi_resource" "resource_group" {
  type      = "Microsoft.Resources/resourceGroups@2024-03-01"
  name      = "rg-ipam-example"
  parent_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}"
  location  = "uksouth"
}

module "ipam" {
  source = "../../"

  resource_group_name  = azapi_resource.resource_group.name
  location             = azapi_resource.resource_group.location
  storage_account_name = "ipamexample001"

  # Platform identity: creates pools with the ipam provider and can delete documents.
  platform_principal_ids = ["00000000-0000-0000-0000-00000000aaaa"]

  # Grants need only pool IDs, so they can be applied before the pools exist.
  environments = {
    prod = {
      pool_ids      = ["uks-prod", "ukw-prod"]
      principal_ids = ["00000000-0000-0000-0000-000000000001"]
    }
    dev = {
      pool_ids      = ["uks-dev"]
      principal_ids = ["00000000-0000-0000-0000-000000000002"]
    }
  }

  tags = {
    purpose = "ipam"
  }
}
