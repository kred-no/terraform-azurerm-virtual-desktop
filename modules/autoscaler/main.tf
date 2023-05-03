////////////////////////
// Variables
////////////////////////

variable "config" {}

vaiable "host_pool" {}

////////////////////////
// Autoscaler Plan
////////////////////////

resource "azurerm_virtual_desktop_scaling_plan" "MAIN" {
  name          = var.config.autoscaler_plan_name
  friendly_name = var.config.autoscaler_plan_friendly_name
  description   = var.config.autoscaler_plan_description
  time_zone     = var.config.autoscaler_plan_timezone

  host_pool {
    hostpool_id          = var.host_pool.id
    scaling_plan_enabled = var.config.autoscaler_plan_enabled
  }

  dynamic "schedule" {
    for_each = var.autoscaler_plan_schedules

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

  location            = data.azurerm_resource_group.MAIN.location
  resource_group_name = data.azurerm_resource_group.MAIN.name
}
