
output "provider_config" {
  description = "Backend settings to hand to the consuming teams (account_url and container)."
  value       = module.ipam.provider_config
}

output "backend_url" {
  description = "ipam backend URL for the CLI and IPAM_BACKEND."
  value       = module.ipam.backend_url
}

output "storage_account_id" {
  description = "Resource ID of the ipam storage account."
  value       = module.ipam.storage_account_id
}

output "team_pools" {
  description = "Pool ID => CIDR for each consuming team."
  value       = { for pool_id, pool in ipam_pool.team : pool_id => one(pool.cidrs) }
}
