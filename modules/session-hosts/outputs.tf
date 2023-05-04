////////////////////////
// Module Outputs
////////////////////////

output "virtual_machines" {
  sensitive = false
  value     = azurerm_windows_virtual_machine.MAIN[*]
}

output "application_security_group" {
  sensitive = false
  value     = azurerm_application_security_group.MAIN
}

output "shared_image" {
  sensitive = false
  value     = one(data.azurerm_shared_image.MAIN[*])
}
