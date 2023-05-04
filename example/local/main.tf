//////////////////////////////////
// Example Configuration
//////////////////////////////////

locals {
  prefix   = "AVD"
  location = "northeurope"
  network  = "10.99.99.0/24"

  session_host_count = 1
  session_host_size  = "Standard_DS2_v2"
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
    maximum_sessions_allowed = 5
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
