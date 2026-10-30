
provider "azurerm" {
  features {}

  # The module disables shared key access, so data-plane calls must use Entra ID.
  storage_use_azuread = true
}
