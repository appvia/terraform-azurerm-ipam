
terraform {
  required_version = "~> 1.9"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.8"
    }
    ipam = {
      source  = "appvia/ipam"
      version = "~> 0.1"
    }
  }
}
