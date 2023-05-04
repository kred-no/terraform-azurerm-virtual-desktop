////////////////////////
// Module Outputs
////////////////////////

output "admin_group" {
  sensitive = false
  value     = azuread_group.ADMIN
}

output "user_group" {
  sensitive = false
  value     = azuread_group.USER
}
