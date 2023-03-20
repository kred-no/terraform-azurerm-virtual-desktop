# Example: minimal

Uses default variables. Will create a resource group & virtual network.
These resources are passed into the module, alon with the minumum required other variables (subnet name & prefixes).

### RESOURCES CREATED(ish)

  * Session Host Subnet  w/NSG + 1 x rule for allowing RDP
  * 1 x Host Pool
  * 1 x Host (AAD joined + added to host-pool), using Windows 11 w/M365 as source image.
  * 2 x New AAD groups (AVD Users and AVD Admins)
  * 1 x Auto-scaling plan
  * 2 x Workspaces; Remote Desktop & 1 x RemoteApp (Notepad)
  * 1 x Azure Vault w/Local Admin credentials
  * Azure Monitoring Workspace (Analytics)

### REQUIREMENTS

  * Azure credentials