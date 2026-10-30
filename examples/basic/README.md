# Basic

Provisions the ipam storage account and container with one platform identity and two environments (`prod` with pools `uks-prod` and `ukw-prod`, `dev` with pool `uks-dev`).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.9 |
| <a name="requirement_azapi"></a> [azapi](#requirement\_azapi) | ~> 2.8 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azapi"></a> [azapi](#provider\_azapi) | ~> 2.8 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_ipam"></a> [ipam](#module\_ipam) | ../../ | n/a |

## Resources

| Name | Type |
|------|------|
| [azapi_resource.resource_group](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource) | resource |

## Inputs

No inputs.

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_backend_url"></a> [backend\_url](#output\_backend\_url) | ipam backend URL for the CLI and IPAM\_BACKEND. |
| <a name="output_provider_config"></a> [provider\_config](#output\_provider\_config) | Value for provider "ipam" { azure\_blob = ... }. |
<!-- END_TF_DOCS -->
