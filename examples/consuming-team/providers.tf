
## Authenticates as the team's deploy identity through ARM_* variables
## (client secret, OIDC or managed identity). No secret belongs in this file.
provider "ipam" {
  azure_blob = {
    account_url = var.account_url
    container   = var.container
  }

  access_propagation_timeout = var.access_propagation_timeout
}
