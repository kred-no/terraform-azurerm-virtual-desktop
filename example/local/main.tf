//////////////////////////////////
// Example Configuration
//////////////////////////////////

locals {
  prefix   = "AVD"
  location = "northeurope"
  network  = "10.99.99.0/24"

  session_host_count   = 2
  session_host_size    = "Standard_DS2_v2"
  max_sessions_allowed = 5
  scaling_enabled      = true
}

//////////////////////////////////
// Required Resources
//////////////////////////////////

resource "random_string" "RESOURCE_GROUP_ID" {
  length  = 5
  upper   = false
  special = false

  keepers = {
    prefix = local.prefix
  }
}

resource "azurerm_resource_group" "MAIN" {
  name     = format("%s-%s", random_string.RESOURCE_GROUP_ID.keepers.prefix, random_string.RESOURCE_GROUP_ID.result)
  location = local.location
}

resource "azurerm_virtual_network" "MAIN" {
  name          = "AvdNetwork"
  address_space = [cidrsubnet(local.network, 0, 0)]

  resource_group_name = azurerm_resource_group.MAIN.name
  location            = azurerm_resource_group.MAIN.location
}

resource "azurerm_subnet" "MAIN" {
  name             = "SessionHosts"
  address_prefixes = [cidrsubnet(local.network, 2, 0)]

  virtual_network_name = azurerm_virtual_network.MAIN.name
  resource_group_name  = azurerm_virtual_network.MAIN.resource_group_name
}

//////////////////////////////////
// Module Config
//////////////////////////////////

module "AZURE_VIRTUAL_DESKTOP" {
  source = "./../../../terraform-azurerm-virtual-desktop"

  // Module Config
  avd_group_users  = { display_name = "Demo AVD Users" }
  avd_group_admins = { display_name = "Demo AVD Admins" }

  host_pool = {
    name                     = "DefaultHostPool"
    load_balancer_type       = "BreadthFirst"
    maximum_sessions_allowed = local.max_sessions_allowed
  }

  scaling_plan = {
    name    = "default-scaling-plan"
    enabled = local.scaling_enabled

    schedules = [{
      name                 = "Weekdays"
      days_of_week         = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
      
      ramp_up_start_time   = "06:00"
      peak_start_time      = "08:00"
      ramp_down_start_time = "15:30"
      off_peak_start_time  = "21:00"
      
      ramp_up_minimum_hosts_percent      = 25
      ramp_up_capacity_threshold_percent = 75
      }, {
      name                 = "Weekend"
      days_of_week         = ["Saturday"]
      
      ramp_up_start_time   = "07:00"
      peak_start_time      = "08:00"
      ramp_down_start_time = "15:30"
      off_peak_start_time  = "18:00"

      ramp_up_minimum_hosts_percent      = 25
      ramp_up_capacity_threshold_percent = 75
    }]
  }

  session_hosts = {
    prefix = "w11sh"
    count  = local.session_host_count
    size   = local.session_host_size
  }

  workspaces = [{
    name = "MyWorkspace"

    application_groups = [{
      name = "RemoteDesktop"
      type = "Desktop"
    }]
  }]

  // Resource References
  resource_group = azurerm_resource_group.MAIN
  subnet         = azurerm_subnet.MAIN
}
