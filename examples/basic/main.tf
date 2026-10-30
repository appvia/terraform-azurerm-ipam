#####################################################################################
# Terraform module examples are meant to show an _example_ on how to use a module
# per use-case. The code below should not be copied directly but referenced in order
# to build your own root module that invokes this module
#####################################################################################

resource "azurerm_resource_group" "ipam" {
  name     = "rg-ipam-example"
  location = "uksouth"
}

module "ipam" {
  source = "../../"

  resource_group_name  = azurerm_resource_group.ipam.name
  location             = azurerm_resource_group.ipam.location
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
