////////////////////////
// Azure AD | Groups
////////////////////////

resource "azuread_group" "ADMIN" {
  display_name            = var.parameters.group_admins.display_name
  prevent_duplicate_names = true
  security_enabled        = true
  owners                  = [var.client_config.object_id]

  lifecycle {
    ignore_changes = [owners]
  }
}

resource "azuread_group" "USER" {
  display_name            = var.parameters.group_users.display_name
  prevent_duplicate_names = true
  security_enabled        = true
  owners                  = [var.client_config.object_id]

  lifecycle {
    ignore_changes = [owners]
  }
}

////////////////////////
// Azure AD | Roles
////////////////////////

resource "azurerm_role_assignment" "ADMINS" {
  for_each = toset([
    "Desktop Virtualization User",
    "Virtual Machine Administrator Login",
  ])

  role_definition_name = each.value
  principal_id         = azuread_group.ADMIN.id
  scope                = var.resource_group.id
}

resource "azurerm_role_assignment" "USERS" {
  for_each = toset([
    "Desktop Virtualization User",
    "Virtual Machine User Login",
  ])

  role_definition_name = each.value
  principal_id         = azuread_group.USER.id
  scope                = var.resource_group.id
}
