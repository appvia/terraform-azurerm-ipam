
terraform {
  required_version = "~> 1.9"

  required_providers {
    ipam = {
      source  = "appvia/ipam"
      version = "~> 0.1"
    }
  }
}
