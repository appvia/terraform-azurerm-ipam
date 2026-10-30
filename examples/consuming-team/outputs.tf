
output "pool_cidrs" {
  description = "CIDRs of the team's pool."
  value       = data.ipam_pool.team.cidrs
}

output "subnet_cidrs" {
  description = "Subnet name => allocated CIDR."
  value       = { for name, allocation in ipam_allocation.subnet : name => allocation.cidr }
}
