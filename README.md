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

> NOTE: Terraform will fail to update any VMs (due to 'Extensions') that are shut-down from 'Scaling Plan' or any other reason. This includes 'destroy' actions on the VMs.

## Resources

  1. https://learn.microsoft.com/en-us/azure/developer/terraform/configure-azure-virtual-desktop
  1. https://learn.microsoft.com/en-us/azure/developer/terraform/create-avd-session-host
  1. https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules
  1. https://github.com/DeanCefola/Azure-WVD/blob/master/PowerShell/New-WVDSessionHost.ps1
  1. https://wiki.techstormpc.com/docs/azure-virtual-desktop

## TODO

  1. Make the name of the AVD Scaling Plan role customizable
