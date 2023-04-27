//////////////////////////////////
// Example Configuration
//////////////////////////////////

locals {
  prefix           = "AzureVirtualDesktop"
  location         = "northeurope"
  address_space    = ["10.99.99.0/24"]
  address_prefixes = ["10.99.99.0/26"]
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
  address_space = local.address_space

  resource_group_name = azurerm_resource_group.MAIN.name
  location            = azurerm_resource_group.MAIN.location
}

resource "azurerm_subnet" "MAIN" {
  name             = format("%s-Subnet", local.prefix)
  address_prefixes = local.address_prefixes

  virtual_network_name = azurerm_virtual_network.MAIN.name
  resource_group_name  = azurerm_virtual_network.MAIN.resource_group_name
}

//////////////////////////////////
// Module Config
//////////////////////////////////

module "AVD" {
  source = "./../../../terraform-azurerm-virtual-desktop"

  // Module Config
  # N/A

  // Resource References
  resource_group = azurerm_resource_group.MAIN
  subnet         = azurerm_subnet.MAIN
}
