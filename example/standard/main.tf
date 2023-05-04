//////////////////////////////////
// Example Configuration
//////////////////////////////////

locals {
  prefix   = "AzureVirtualDesktop"
  location = "northeurope"
  network  = "10.99.99.0/24"

  session_host_count = 0
  session_host_size  = "Standard_DS2_v2"
}

//////////////////////////////////
// Required Resources
//////////////////////////////////

resource "random_id" "RESOURCE_GROUP_ID" {
  keepers = {
    prefix = local.prefix
  }

  byte_length = 3
}

resource "azurerm_resource_group" "MAIN" {
  name     = join("-", [random_id.RESOURCE_GROUP_ID.keepers.prefix, random_id.RESOURCE_GROUP_ID.hex])
  location = local.location
}

resource "azurerm_virtual_network" "MAIN" {
  name          = format("%s-VirtualNetwork", local.prefix)
  address_space = [cidrsubnet(local.network, 0, 0)]

  resource_group_name = azurerm_resource_group.MAIN.name
  location            = azurerm_resource_group.MAIN.location
}

resource "azurerm_subnet" "MAIN" {
  name             = format("%s-Subnet", local.prefix)
  address_prefixes = [cidrsubnet(local.network, 2, 0)]

  virtual_network_name = azurerm_virtual_network.MAIN.name
  resource_group_name  = azurerm_virtual_network.MAIN.resource_group_name
}

//////////////////////////////////
// Module Config
//////////////////////////////////

module "VIRTUAL_DESKTOP" {
  source = "./../../../terraform-azurerm-virtual-desktop"

  // Module Config
  avd_group_users  = { display_name = "Demo AVD Users" }
  avd_group_admins = { display_name = "Demo AVD Admins" }

  host_pool = {
    name                     = "primary-pool"
    load_balancer_type       = "BreadthFirst"
    maximum_sessions_allowed = 3
  }

  session_hosts = {
    prefix         = "shvm"
    count          = local.session_host_count
    size           = local.session_host_size
  }

  workspaces = [{
    name = "DefaultWorkspace"

    application_groups = [{
      name = "ExampleRemoteDesktop"
      type = "Desktop"
    }]
  }]

  // Resource References
  resource_group = azurerm_resource_group.MAIN
  subnet         = azurerm_subnet.MAIN
}
