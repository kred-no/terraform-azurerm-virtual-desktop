////////////////////////
// Variables
////////////////////////

////////////////////////
// Desktop Workspace
////////////////////////

resource "azurerm_virtual_desktop_workspace" "MAIN" {
  for_each = {
    for ws in var.workspaces : ws.name => ws
  }

  name          = each.value["name"]
  friendly_name = each.value["friendly_name"]
  description   = each.value["description"]

  tags                = var.tags
  resource_group_name = data.azurerm_resource_group.MAIN.name
  location            = data.azurerm_resource_group.MAIN.location
}

////////////////////////
// Desktop Application Groups
////////////////////////

resource "azurerm_virtual_desktop_application_group" "MAIN" {
  for_each = {
    for group in var.application_groups : group.name => group
  }

  name                         = each.value["name"]
  type                         = each.value["type"]
  friendly_name                = each.value["friendly_name"]
  description                  = each.value["description"]
  default_desktop_display_name = each.value["default_desktop_display_name"]

  tags                = var.tags
  host_pool_id        = azurerm_virtual_desktop_host_pool.MAIN.id
  resource_group_name = data.azurerm_resource_group.MAIN.name
  location            = data.azurerm_resource_group.MAIN.location
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "MAIN" {
  for_each = {
    for group in var.application_groups : group.name => group
  }

  application_group_id = azurerm_virtual_desktop_application_group.MAIN[each.key].id
  workspace_id         = azurerm_virtual_desktop_workspace.MAIN[each.value["workspace_name"]].id
}

////////////////////////
// Desktop Remote Apps
////////////////////////

resource "azurerm_virtual_desktop_application" "MAIN" {
  for_each = {
    for app in var.applications : join("-", [app.application_group_name, app.name]) => app
  }

  name                         = each.value["name"]
  friendly_name                = each.value["friendly_name"]
  description                  = each.value["description"]
  path                         = each.value["path"]
  command_line_argument_policy = each.value["command_line_argument_policy"]
  command_line_arguments       = each.value["command_line_arguments"]
  show_in_portal               = each.value["show_in_portal"]
  icon_path                    = each.value["icon_path"]
  icon_index                   = each.value["icon_index"]

  application_group_id = azurerm_virtual_desktop_application_group.MAIN[each.value["application_group_name"]].id
}
