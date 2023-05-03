////////////////////////
// Azure Log Analytics Workspace
////////////////////////

resource "azurerm_log_analytics_workspace" "MAIN" {
  name              = var.log_analytics_workspace_name
  sku               = var.log_analytics_workspace_sku
  retention_in_days = var.log_analytics_workspace_retention_days
  daily_quota_gb    = var.log_analytics_workspace_daily_quota_gb

  tags                = var.tags
  location            = data.azurerm_virtual_network.MAIN.location
  resource_group_name = data.azurerm_virtual_network.MAIN.resource_group_name
}

////////////////////////
// Host Pool | Monitoring
////////////////////////

/*resource "azurerm_monitor_diagnostic_setting" "HOST_POOL" {
  name = join("-", [var.log_monitor_prefix, azurerm_virtual_desktop_host_pool.MAIN.name])

  target_resource_id         = azurerm_virtual_desktop_host_pool.MAIN.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.MAIN.id

  dynamic "enabled_log" {

    for_each = [
      "AgentHealthStatus",
      "Checkpoint",
      "Connection",
      "Error",
      "HostRegistration",
      "Management",
      "NetworkData",
      "SessionHostManagement",
    ]

    content {
      category = enabled_log.value

      retention_policy {
        enabled = false
      }
    }
  }
}*/

////////////////////////
// Desktop Workspace | Monitoring
////////////////////////

resource "azurerm_monitor_diagnostic_setting" "APP_WORKSPACE" {
  for_each = {
    for workspace in azurerm_virtual_desktop_workspace.MAIN : workspace.name => workspace.id
    if true
  }

  name                       = join("-", [var.log_monitor_prefix, each.key])
  target_resource_id         = each.value
  log_analytics_workspace_id = azurerm_log_analytics_workspace.MAIN.id

  // See https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/resource-logs-categories#microsoftdesktopvirtualizationworkspaces
  dynamic "enabled_log" {

    for_each = [
      "Checkpoint",
      "Error",
      "Feed",
      "Management",
    ]

    content {
      category = enabled_log.value

      retention_policy {
        enabled = false
      }
    }
  }
}

////////////////////////
// Desktop Application Group | Monitoring
////////////////////////

resource "azurerm_monitor_diagnostic_setting" "APP_GROUP" {
  for_each = {
    for group in azurerm_virtual_desktop_application_group.MAIN : group.name => group.id
    if true
  }

  name                       = join("-", [var.log_monitor_prefix, each.key])
  target_resource_id         = each.value
  log_analytics_workspace_id = azurerm_log_analytics_workspace.MAIN.id

  // See https://learn.microsoft.com/en-us/azure/azure-monitor/essentials/resource-logs-categories#microsoftdesktopvirtualizationapplicationgroups
  dynamic "enabled_log" {

    for_each = [
      "Checkpoint",
      "Error",
      "Management",
    ]

    content {
      category = enabled_log.value

      retention_policy {
        enabled = false
      }
    }
  }
}

////////////////////////
// Autoscaler Monitoring
////////////////////////
/*
resource "azurerm_monitor_diagnostic_setting" "AUTOSCALER" {
  name = join("-", [var.log_monitor_prefix, azurerm_virtual_desktop_scaling_plan.MAIN.name])

  depends_on = [
    azurerm_virtual_desktop_scaling_plan.MAIN,
  ]

  target_resource_id         = azurerm_virtual_desktop_scaling_plan.MAIN.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.MAIN.id

  enabled_log {
    category = "Autoscale"

    retention_policy {
      enabled = false
    }
  }
}
*/
# END