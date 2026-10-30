# Basic

Provisions the ipam storage account and container with one platform identity and two environments (`prod` with pools `uks-prod` and `ukw-prod`, `dev` with pool `uks-dev`).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.9.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.14.0, < 6.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | >= 4.14.0, < 6.0.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ipam"></a> [ipam](#module\_ipam) | ../../ | n/a |

## Resources

| Name | Type |
|------|------|
| [azurerm_resource_group.ipam](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) | resource |

## Inputs

No inputs.

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_backend_url"></a> [backend\_url](#output\_backend\_url) | ipam backend URL for the CLI and IPAM\_BACKEND. |
| <a name="output_provider_config"></a> [provider\_config](#output\_provider\_config) | Value for provider "ipam" { azure\_blob = ... }. |
<!-- END_TF_DOCS -->
