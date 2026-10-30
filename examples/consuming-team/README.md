# Consuming team

A consuming team's root module. It reads its pool from the platform team's ipam container and allocates one CIDR per subnet from it with `ipam_allocation`.

Configure it with the platform team's `provider_config` (`account_url`, `container`) and the team's pool ID, and authenticate as the team's deploy identity through `ARM_*` variables (for example `ARM_TENANT_ID`, `ARM_CLIENT_ID` and `ARM_CLIENT_SECRET`, or `ARM_USE_OIDC=true` in a pipeline). The team can read every pool and reservations document, but its writes are limited to `reservations/<its pool>.json`: pointing `pool_id` at another team's pool fails with access denied (`AuthorizationPermissionMismatch`).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | ~> 1.9 |
| <a name="requirement_ipam"></a> [ipam](#requirement\_ipam) | ~> 0.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_ipam"></a> [ipam](#provider\_ipam) | ~> 0.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [ipam_allocation.subnet](https://registry.terraform.io/providers/appvia/ipam/latest/docs/resources/allocation) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_account_url"></a> [account\_url](#input\_account\_url) | Blob endpoint of the ipam storage account (provider\_config.account\_url from the platform team). | `string` | n/a | yes |
| <a name="input_pool_id"></a> [pool\_id](#input\_pool\_id) | ID of the pool this team allocates from. | `string` | n/a | yes |
| <a name="input_access_propagation_timeout"></a> [access\_propagation\_timeout](#input\_access\_propagation\_timeout) | How long writes retry access denied while new role assignments take effect. | `string` | `"5m"` | no |
| <a name="input_container"></a> [container](#input\_container) | Name of the ipam container (provider\_config.container from the platform team). | `string` | `"ipam"` | no |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | Subnet name => prefix length to allocate from the pool. | `map(number)` | <pre>{<br/>  "app": 24,<br/>  "data": 26<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_pool_cidrs"></a> [pool\_cidrs](#output\_pool\_cidrs) | CIDRs of the team's pool. |
| <a name="output_subnet_cidrs"></a> [subnet\_cidrs](#output\_subnet\_cidrs) | Subnet name => allocated CIDR. |
<!-- END_TF_DOCS -->
