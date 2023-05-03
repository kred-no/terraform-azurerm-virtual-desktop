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

output "network_interfaces" {
  sensitive = false
  
  value = [
    azurerm_network_interface.MAIN[*]
  ]
}

output "application_security_group" {
  sensitive = false
  value     = azurerm_application_security_group.MAIN
}

output "virtual_desktop_host_pool" {
  sensitive = false
  value     = azurerm_virtual_desktop_host_pool.MAIN
}

output "log_analytics_workspace" {
  sensitive = false
  value     = azurerm_log_analytics_workspace.MAIN
}

output "key_vault" {
  sensitive = true
  value     = one(azurerm_key_vault.MAIN[*])
}
