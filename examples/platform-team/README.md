# Platform team

The platform team's root module. It creates the ipam storage account and container with the module, then creates the pool hierarchy with the ipam provider: a `platform` root pool (`10.0.0.0/8`) and one child pool per consuming team (`team-a`, `team-b`).

The identity running the apply (az login or `ARM_*` variables) becomes the platform identity: it gets "Storage Blob Data Contributor" on the container and is the only identity that can write `pools/*`. Each team's principal IDs get read access plus a write grant limited to `reservations/<its pool>.json`, so team A can allocate from `team-a` but not from `team-b`.

Hand the `provider_config` output to the consuming teams (see [consuming-team](../consuming-team)).

<!-- BEGIN_TF_DOCS -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (~> 1.9)

- <a name="requirement_azapi"></a> [azapi](#requirement\_azapi) (~> 2.8)

- <a name="requirement_ipam"></a> [ipam](#requirement\_ipam) (~> 0.1)

## Providers

The following providers are used by this module:

- <a name="provider_azapi"></a> [azapi](#provider\_azapi) (~> 2.8)

- <a name="provider_ipam"></a> [ipam](#provider\_ipam) (~> 0.1)

## Modules

The following Modules are called:

### <a name="module_ipam"></a> [ipam](#module\_ipam)

Source: ../../

Version:

## Resources

The following resources are used by this module:

- [ipam_pool.root](https://registry.terraform.io/providers/appvia/ipam/latest/docs/resources/pool) (resource)
- [ipam_pool.team](https://registry.terraform.io/providers/appvia/ipam/latest/docs/resources/pool) (resource)

## Required Inputs

The following input variables are required:

### <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name)

Description: Name of the existing resource group for the ipam storage account.

Type: `string`

### <a name="input_storage_account_name"></a> [storage\_account\_name](#input\_storage\_account\_name)

Description: Globally unique name of the ipam storage account.

Type: `string`

### <a name="input_team_a_principal_ids"></a> [team\_a\_principal\_ids](#input\_team\_a\_principal\_ids)

Description: Object IDs of team A's deploy identities. They may allocate only from the team-a pool.

Type: `list(string)`

### <a name="input_team_b_principal_ids"></a> [team\_b\_principal\_ids](#input\_team\_b\_principal\_ids)

Description: Object IDs of team B's deploy identities. They may allocate only from the team-b pool.

Type: `list(string)`

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_environment_role"></a> [environment\_role](#input\_environment\_role)

Description: How the consuming teams get write access to their reservations documents (builtin or custom).

Type: `string`

Default: `"builtin"`

### <a name="input_location"></a> [location](#input\_location)

Description: Azure region for the storage account.

Type: `string`

Default: `"uksouth"`

### <a name="input_tags"></a> [tags](#input\_tags)

Description: Tags applied to the storage account.

Type: `map(string)`

Default: `{}`

## Outputs

The following outputs are exported:

### <a name="output_backend_url"></a> [backend\_url](#output\_backend\_url)

Description: ipam backend URL for the CLI and IPAM\_BACKEND.

### <a name="output_provider_config"></a> [provider\_config](#output\_provider\_config)

Description: Backend settings to hand to the consuming teams (account\_url and container).

### <a name="output_storage_account_id"></a> [storage\_account\_id](#output\_storage\_account\_id)

Description: Resource ID of the ipam storage account.

### <a name="output_team_pools"></a> [team\_pools](#output\_team\_pools)

Description: Pool ID => CIDR for each consuming team.
<!-- END_TF_DOCS -->
