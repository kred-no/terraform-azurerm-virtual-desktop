//////////////////////////////////
// Module
//////////////////////////////////

variable "azure" {
  type = object({
    subscription_id = string
    tenant_id       = string
  })

  default = null
}
