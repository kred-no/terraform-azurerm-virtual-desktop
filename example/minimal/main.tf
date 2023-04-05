//////////////////////////////////
// Example Configuration
//////////////////////////////////

locals {
  prefix        = "AzureVirtualDesktop"
  location      = "northeurope"
  address_space = ["10.99.99.0/24"]
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
  name          = join("", [local.prefix, "VNet"])
  address_space = local.address_space

  resource_group_name = azurerm_resource_group.MAIN.name
  location            = azurerm_resource_group.MAIN.location
}

//////////////////////////////////
// Module Config
//////////////////////////////////

module "AVD" {
  source = "./../../../terraform-azurerm-virtual-desktop"

  // Module Config
  subnet_prefixes = {
    newbits = 2
  }

  // Resource References
  resource_group  = azurerm_resource_group.MAIN
  virtual_network = azurerm_virtual_network.MAIN
}
