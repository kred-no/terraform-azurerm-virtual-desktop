////////////////////////
// Data Sources
////////////////////////

data "azuread_service_principal" "AUTOSCALER" {
  display_name = "Windows Virtual Desktop"
}

////////////////////////
// Autoscaler Role
////////////////////////

resource "azurerm_role_definition" "AUTOSCALER" {
  name        = "avd-autoscaler-custom-role"
  description = "Custom Autoscaler Role (Azure Virtual Desktop)"
  scope       = var.arm_subscription.id

  permissions {
    actions = [
      "Microsoft.Insights/eventtypes/values/read",
      "Microsoft.Compute/virtualMachines/deallocate/action",
      "Microsoft.Compute/virtualMachines/restart/action",
      "Microsoft.Compute/virtualMachines/powerOff/action",
      "Microsoft.Compute/virtualMachines/start/action",
      "Microsoft.Compute/virtualMachines/read",
      "Microsoft.DesktopVirtualization/hostpools/read",
      "Microsoft.DesktopVirtualization/hostpools/write",
      "Microsoft.DesktopVirtualization/hostpools/sessionhosts/read",
      "Microsoft.DesktopVirtualization/hostpools/sessionhosts/write",
      "Microsoft.DesktopVirtualization/hostpools/sessionhosts/usersessions/delete",
      "Microsoft.DesktopVirtualization/hostpools/sessionhosts/usersessions/read",
      "Microsoft.DesktopVirtualization/hostpools/sessionhosts/usersessions/sendMessage/action",
      "Microsoft.DesktopVirtualization/hostpools/sessionhosts/usersessions/read"
    ]

    not_actions = []
  }

  assignable_scopes = [
    var.arm_subscription.id,
  ]
}

resource "azurerm_role_assignment" "AUTOSCALER" {
  principal_id       = data.azuread_service_principal.AUTOSCALER.id
  role_definition_id = azurerm_role_definition.AUTOSCALER.role_definition_resource_id

  skip_service_principal_aad_check = true
  scope                            = var.arm_subscription.id
}

////////////////////////
// Autoscaler Plan
////////////////////////

resource "azurerm_virtual_desktop_scaling_plan" "MAIN" {
  depends_on = [
    azurerm_role_assignment.AUTOSCALER,
  ]

  name          = var.parameters.name
  friendly_name = var.parameters.friendly_name
  description   = var.parameters.description
  time_zone     = var.parameters.time_zone

  host_pool {
    hostpool_id          = var.host_pool.id
    scaling_plan_enabled = var.parameters.enabled
  }

  dynamic "schedule" {
    for_each = var.parameters.schedules

    content {
      name                                 = schedule.value["name"]
      days_of_week                         = schedule.value["days_of_week"]
      ramp_up_start_time                   = schedule.value["ramp_up_start_time"]
      ramp_up_load_balancing_algorithm     = schedule.value["ramp_up_load_balancing_algorithm"]
      ramp_up_minimum_hosts_percent        = schedule.value["ramp_up_minimum_hosts_percent"]
      ramp_up_capacity_threshold_percent   = schedule.value["ramp_up_capacity_threshold_percent"]
      peak_start_time                      = schedule.value["peak_start_time"]
      peak_load_balancing_algorithm        = schedule.value["peak_load_balancing_algorithm"]
      ramp_down_start_time                 = schedule.value["ramp_down_start_time"]
      ramp_down_load_balancing_algorithm   = schedule.value["ramp_down_load_balancing_algorithm"]
      ramp_down_minimum_hosts_percent      = schedule.value["ramp_down_minimum_hosts_percent"]
      ramp_down_force_logoff_users         = schedule.value["ramp_down_force_logoff_users"]
      ramp_down_wait_time_minutes          = schedule.value["ramp_down_wait_time_minutes"]
      ramp_down_notification_message       = schedule.value["ramp_down_notification_message"]
      ramp_down_capacity_threshold_percent = schedule.value["ramp_down_capacity_threshold_percent"]
      ramp_down_stop_hosts_when            = schedule.value["ramp_down_stop_hosts_when"]
      off_peak_start_time                  = schedule.value["off_peak_start_time"]
      off_peak_load_balancing_algorithm    = schedule.value["off_peak_load_balancing_algorithm"]
    }
  }

  location            = var.resource_group.location
  resource_group_name = var.resource_group.name
}
