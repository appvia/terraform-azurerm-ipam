
output "backend_url" {
  description = "ipam backend URL for the container (azblob://<account>.blob.core.windows.net/<container>/). Built only from inputs, so it is known at plan time."
  value       = "azblob://${var.storage_account_name}.blob.core.windows.net/${var.container_name}/"
}

output "storage_account_id" {
  description = "Resource ID of the storage account."
  value       = azapi_resource.storage_account.id
}

output "container_name" {
  description = "Name of the ipam container."
  value       = azapi_resource.container.name
}

output "provider_config" {
  description = "Object for the ipam provider's azure_blob block (provider \"ipam\" { azure_blob = module.ipam.provider_config }). Built only from inputs, so it is known at plan time."
  value = {
    account_url = local.blob_endpoint
    container   = var.container_name
  }
}
