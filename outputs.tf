output "resource_group" {
  sensitive = false
  value     = data.azurerm_resource_group.MAIN
}

output "virtual_network" {
  sensitive = false
  value     = data.azurerm_virtual_network.MAIN
}

output "subnet" {
  sensitive = false
  value     = data.azurerm_subnet.MAIN
}

output "application_security_group" {
  sensitive = false
  value     = module.SESSION_HOSTS.application_security_group
}

output "admin_group" {
  sensitive = false
  value     = module.AZURE_AD_GROUPS.admin_group
}

output "user_group" {
  sensitive = false
  value     = module.AZURE_AD_GROUPS.user_group
}

output "session_hosts" {
  sensitive = true
  value     = module.SESSION_HOSTS.virtual_machines
}
