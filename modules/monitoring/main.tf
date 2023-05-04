////////////////////////
// Module Variables
////////////////////////

variable "parameters" {}
variable "tags" {}
variable "virtual_network" {}
variable "host_pool" {}
variable "workspaces" {}

////////////////////////
// Module Outputs
////////////////////////
// N/A

////////////////////////
// Azure Log Analytics Workspace
////////////////////////

resource "azurerm_log_analytics_workspace" "MAIN" {
  name              = var.parameters.workspace_name
  sku               = var.parameters.workspace_sku
  retention_in_days = var.parameters.workspace_retention_days
  daily_quota_gb    = var.parameters.workspace_daily_quota_gb

  tags                = var.tags
  location            = var.virtual_network.location
  resource_group_name = var.virtual_network.resource_group_name
}

////////////////////////
// Desktop Application Group | Monitoring
////////////////////////

resource "azurerm_monitor_diagnostic_setting" "APP_GROUP" {
  for_each = {
    for app_group in azurerm_virtual_desktop_application_group.MAIN : app_group.name => app_group
    if true
  }

  name                       = format("%s-%s", var.parameters.prefix, each.value["name"])
  target_resource_id         = each.value["id"]
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