# azure-tf-vms
## What is this
This is a quick terraform script to help you setup azure VM(s) in a single VPC/Subnet with public hostnames. The script supports creating multiple VMs using a vm_map cli argument. At the moment, the vm_map requires a name and a private-ip-address within subnet cidr `10.0.2.0/24`. For example of vm_map input, see [this](#dont-need-two-vms-or-change-other-settings)
## Prerequisites
```shell 
## install terraform
## install az cli
$> az login
## az group create 
```

## To use the tfscript
```shell
$> git clone https://github.com/amitgupta7/azure-tf-vms.git
$> cd azure-tf-vms
$> source tfAlias
$> tf init 
## provision infra for pods provide EXISTING resource group name,
## azure subscription-id and vm-password on prompt
$> tfaa 
## to de-provision provide EXISTING resource group name, 
## azure subscription-id and vm-password on prompt 
## EXACTLY SAME VALUES AS PROVIDED DURING PROVISIONING
$> tfda
```
## Don't need two VMs (or change other settings)?
Default creates two vm nodes. To override pass the vm map in cli. Other Variables are defined in var.tf file, and can be overridden using cli input or tfvar file.

Note: other vriables like vm os, os disk size, vm-size, subnet cidr etc can be specified as cli input. see `var.tf` file for details.

E.g. 
```shell
## creaet a single node cluster
$> tfa -var=vm_map='{"pod1":{"private_ip_address":"10.0.2.21"}}'
## creaet a two node cluster (default) in eastus2 (instead of default westus2)
tfa -var=location=eastus2
## create a 3 node cluster
$> tfa -var=vm_map='{"pod1":{"private_ip_address":"10.0.2.21"}, "pod2":{"private_ip_address":"10.0.2.22"}, "pod3":{"private_ip_address":"10.0.2.23"}}'
```
Alternatively create a `terraform.tfvars` file to override the variables like location and vm_map. e.g.
```hcl
az_subscription_id = "azure-subscription-guid"
az_resource_group  = "existing-resource-group"
azpwd              = "strongPwd"
location           = "eastus2"
vm_map             = {"pod1":{"private_ip_address":"10.0.2.21"},"pod2":{"private_ip_address":"10.0.2.22"}, "pod3":{"private_ip_address":"10.0.2.23"}}
```
## Output (IMPORTANT: please save)
NOTE: The script will output the hostnames and mandatory parameters (for delete).
```shell
az_resource_group = "your-az-resource-group"
az_subscription_id = "your-az-subscription-guid-value"
hostnames = [
  "azure-tf-vms-pod1.eastus2.cloudapp.azure.com",
  "azure-tf-vms-pod2.eastus2.cloudapp.azure.com",
  "azure-tf-vms-pod3.eastus2.cloudapp.azure.com"
]
ssh_credentials = "azuser/yourStringPasswordHere"
```
