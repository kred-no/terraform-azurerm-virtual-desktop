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
