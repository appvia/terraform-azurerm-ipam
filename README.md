<!-- markdownlint-disable -->

<a href="https://www.appvia.io/"><img src="https://raw.githubusercontent.com/appvia/terraform-azurerm-ipam/refs/heads/main/docs/banner.jpg" alt="Appvia Banner"/></a><br/><p align="right"> </a> <a href="https://registry.terraform.io/modules/appvia/ipam/azurerm/latest"><img src="https://img.shields.io/static/v1?label=APPVIA&message=Terraform%20Registry&color=191970&style=for-the-badge" alt="Terraform Registry"/></a> <a href="https://github.com/appvia/terraform-azurerm-ipam/releases/latest"><img src="https://img.shields.io/github/release/appvia/terraform-azurerm-ipam.svg?style=for-the-badge&color=006400" alt="Latest Release"/></a> <a href="https://appvia-community.slack.com/join/shared_invite/zt-1s7i7xy85-T155drryqU56emm09ojMVA#/shared-invite/email"><img src="https://img.shields.io/badge/Slack-Join%20Community-purple?style=for-the-badge&logo=slack" alt="Slack Community"/></a> <a href="https://github.com/appvia/terraform-azurerm-ipam/graphs/contributors"><img src="https://img.shields.io/github/contributors/appvia/terraform-azurerm-ipam.svg?style=for-the-badge&color=FF8C00" alt="Contributors"/></a>

<!-- markdownlint-restore -->
<!--
  ***** CAUTION: Placeholders (terraform-azurerm-ipam, ipam) are managed by scripts/init-from-template.sh ******
-->

![Github Actions](https://github.com/appvia/terraform-azurerm-ipam/actions/workflows/terraform.yml/badge.svg)

# Terraform Azure IPAM storage

## Description

Provisions the Azure Blob backend for the [ipam provider](https://github.com/appvia/terraform-provider-ipam) and the `ipam` CLI, together with the access rules that make the storage the permission boundary:

- A hardened storage account: flat namespace (`is_hns_enabled = false`), TLS 1.2, shared key access disabled, no public blob access, blob versioning, and blob and container soft delete.
- A private container (`ipam` by default) that holds `pools/<pool_id>.json` (pool definitions) and `reservations/<pool_id>.json` (allocations).
- **Platform identities** (`platform_principal_ids`): "Storage Blob Data Contributor" on the container. Only they can write pool definitions, create reservations documents and delete anything.
- **Environment identities** (`environments`): "Storage Blob Data Reader" on the container, plus a write grant conditioned on the blob path, so each environment can overwrite only `reservations/<pool_id>.json` for its own pools. An environment with no pools is read-only.
- **Readers** (`reader_principal_ids`): "Storage Blob Data Reader" on the container.

All role assignments are scoped to the container; the module grants nothing at account scope. It does not create pools or configure the ipam provider.

### Environment write access (`environment_role`)

- `builtin` (default): no custom role is created. The built-in "Storage Blob Data Contributor" role is assigned with a condition that allows `blobs/write` only on the same paths and never allows `blobs/delete`, `blobs/add/action` or `blobs/move/action`. **Warning:** that built-in role also carries management-plane actions (`containers/delete`, `containers/write`) that conditions cannot restrict. The account's `CanNotDelete` lock blocks container deletion through ARM, but environment identities can still modify the container, and container soft delete is the only protection for data-plane deletes. Use `custom` where you need to rule that out.
- `custom`: the module creates a custom role named `ipam-reservations-writer-<storage_account_name>-<container_name>` (custom role names are unique per tenant) whose only permissions are the data actions `Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read` and `.../blobs/write`. There is no delete, no `add/action` and no management-plane action. It is assigned with an ABAC condition (version 2.0) that allows `blobs/write` only when the blob path equals one of the environment's `reservations/<pool_id>.json`. Reservations documents are created by the platform identity, and a release is an overwrite, so environments never need create or delete.

### Notes

- **Grants need only pool IDs**, so this module can be applied before the pools exist. The platform state then creates pools with the ipam provider using `backend_url` / `provider_config`.
- `backend_url` and `provider_config` are built only from input variables, so they are known at plan time and can configure the ipam provider in the same apply as this module.
- **Hierarchical namespace must stay off.** On ADLS Gen2 accounts, renames can bypass blob path conditions, and the ipam azblob backend requires a flat-namespace account.
- Shared key access is disabled, so the module uses the azapi provider and needs no data-plane credentials.
- Principal IDs are used as `for_each` keys and must be known at plan time.
- The storage account and container have `lifecycle { prevent_destroy = true }`, and the account carries a `CanNotDelete` management lock (`ipam-do-not-delete`): they hold the only record of allocated ranges. Remove the lock deliberately before destroying the account.
- Role assignments and the container retry on Azure replication errors (`PrincipalNotFound`, `RoleDefinitionDoesNotExist`, `StorageAccountIsNotProvisioned`) through azapi's `retry`. The account and container also retry deletion while ARM still reports the scope as locked (`ScopeLocked`), which happens briefly after the lock is removed.
- Pool IDs must match `^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$`.

## Verification status

The access rules above describe what the role assignments are written to do. Here's what has actually been tested:

- `terraform test` in this repository, in plan mode against a mocked azapi provider. No real `apply`.
- The rendered role condition text, compared byte for byte with a golden file.
- The ipam Azure Blob backend, exercised on the Azurite emulator by `scripts/e2e.sh` in [terraform-provider-ipam](https://github.com/appvia/terraform-provider-ipam). Azurite authenticates with a connection string and doesn't enforce RBAC or ABAC, so it says nothing about these grants.

Not verified:

- Enforcement of the RBAC role assignments and ABAC conditions by real Azure, including the container-scope assignments.
- The real Azure credential path (aztfauth with `ARM_*` variables) against a real storage account.

How to check the rest:

- **Grant enforcement.** Apply this module, then run `ipam doctor --expect-write <own pool> --expect-no-write <other pool>` as each environment identity. That's the only check of these grants against real Azure RBAC and ABAC. Both flags can be repeated.
- **The provider's real-cloud e2e leg.** Setting `AZURE_STORAGE_ACCOUNT_URL` (plus `AZURE_STORAGE_CONTAINER`) runs `scripts/e2e.sh` in the provider repository against a real container with the **caller's own** `ARM_*` credentials. It proves the real credential path (aztfauth) and real conditional writes. It doesn't apply this module or test its grants.

## Usage

```hcl
module "ipam" {
  source  = "appvia/ipam/azurerm"
  version = "0.0.1"

  resource_group_name    = "rg-ipam"
  location               = "uksouth"
  storage_account_name   = "ipamplatform001"
  platform_principal_ids = ["<platform-object-id>"]

  environments = {
    prod = {
      pool_ids      = ["uks-prod", "ukw-prod"]
      principal_ids = ["<prod-deploy-object-id>"]
    }
  }
}

provider "ipam" {
  azure_blob = module.ipam.provider_config
}
```

## Examples

See the [examples](./examples) directory for working usage examples.

- [Basic](./examples/basic) - Storage, platform access and two environments.

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

No modules.

## Resources

| Name | Type |
|------|------|
| [azapi_resource.container](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource) | resource |
| [azapi_resource.environment_reader](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource) | resource |
| [azapi_resource.environment_writer](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource) | resource |
| [azapi_resource.lock](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource) | resource |
| [azapi_resource.platform](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource) | resource |
| [azapi_resource.reader](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource) | resource |
| [azapi_resource.reservations_writer](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource) | resource |
| [azapi_resource.storage_account](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource) | resource |
| [azapi_update_resource.blob_service](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/update_resource) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_location"></a> [location](#input\_location) | Azure region for the storage account. | `string` | n/a | yes |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | Name of the existing resource group that holds the storage account. | `string` | n/a | yes |
| <a name="input_storage_account_name"></a> [storage\_account\_name](#input\_storage\_account\_name) | Globally unique name of the storage account that holds the ipam documents (3-24 lowercase letters and digits). | `string` | n/a | yes |
| <a name="input_account_replication_type"></a> [account\_replication\_type](#input\_account\_replication\_type) | Replication type of the storage account (for example LRS, ZRS, GRS, GZRS). | `string` | `"GZRS"` | no |
| <a name="input_container_name"></a> [container\_name](#input\_container\_name) | Name of the private blob container that holds pools/ and reservations/. | `string` | `"ipam"` | no |
| <a name="input_environment_role"></a> [environment\_role](#input\_environment\_role) | How environment identities get write access to their reservations documents.<br/>"builtin" (default): the built-in "Storage Blob Data Contributor" role with a condition limiting writes to the environment's reservations/<pool\_id>.json paths and denying blob delete/add/move. This role also carries management-plane actions (containers/delete, containers/write) that conditions cannot restrict; the account's CanNotDelete lock blocks container deletion through ARM, and container soft delete covers the rest.<br/>"custom": a module-created custom role with only blob read/write data actions, conditioned to the same paths. No delete, no add, no management-plane actions. | `string` | `"builtin"` | no |
| <a name="input_environments"></a> [environments](#input\_environments) | Per-environment access. Each entry lists the pool IDs whose reservations/<pool\_id>.json the environment may overwrite, and the object IDs of its deploy identities. Pool IDs are enough; the pools need not exist yet. | <pre>map(object({<br/>    pool_ids      = list(string)<br/>    principal_ids = list(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_platform_principal_ids"></a> [platform\_principal\_ids](#input\_platform\_principal\_ids) | Object IDs of the platform identities. They get "Storage Blob Data Contributor" on the container and are the only identities that can write pools/* or delete documents. | `list(string)` | `[]` | no |
| <a name="input_reader_principal_ids"></a> [reader\_principal\_ids](#input\_reader\_principal\_ids) | Object IDs of identities that only need to read pools and reservations. | `list(string)` | `[]` | no |
| <a name="input_soft_delete_retention_days"></a> [soft\_delete\_retention\_days](#input\_soft\_delete\_retention\_days) | Retention in days for blob and container soft delete. | `number` | `30` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to the storage account. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_backend_url"></a> [backend\_url](#output\_backend\_url) | ipam backend URL for the container (azblob://<account>.blob.core.windows.net/<container>/). Built only from inputs, so it is known at plan time. |
| <a name="output_container_name"></a> [container\_name](#output\_container\_name) | Name of the ipam container. |
| <a name="output_provider_config"></a> [provider\_config](#output\_provider\_config) | Object for the ipam provider's azure\_blob block (provider "ipam" { azure\_blob = module.ipam.provider\_config }). Built only from inputs, so it is known at plan time. |
| <a name="output_storage_account_id"></a> [storage\_account\_id](#output\_storage\_account\_id) | Resource ID of the storage account. |
<!-- END_TF_DOCS -->

## Contributing

Contributions are welcome. Please read the [Code of Conduct](./CODE_OF_CONDUCT.md) before contributing.

## License

This project is licensed under the terms of the [GPL-3.0 license](./LICENSE).
