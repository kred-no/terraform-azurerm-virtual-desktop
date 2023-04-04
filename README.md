# terraform-azurerm-virtual-desktop

Deployment of Azure Virtual Desktop solution (single host-pool; for now..)

| Method                    | URL                                                   |
| :--                       | :--                                                   |
| Azure cloud (most common)	| https://client.wvd.microsoft.com/arm/webclient/       |

## Description

  * Resource Group & Virtual Network resources are not created within the module.
  * Network resources will be created in provided "virtual network" resource group
  * Non-network resources will be created in provided "resource group"
  * Host VMs joined to Azure AD.
  * User Authentication is done via Azure AD groups

## Resources

  * https://learn.microsoft.com/en-us/azure/developer/terraform/configure-azure-virtual-desktop