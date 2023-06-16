variable "az_subscription_id" {
    description = "azure subscription id"
    type = string
}

variable "az_resource_group" {
    description = "resource group to create these resources"
    default = "securiti-sepm"  
}