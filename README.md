# azure-tf-vms
## What is this
This is a quick terraform script to help you setup azure VM(s) in a single VPC/Subnet with public hostnames. The script supports creating multiple VMs using a vm_map cli argument. At the moment, the vm_map requires a name and a private-ip-address within subnet cidr `10.0.2.0/24`. For example of vm_map input, see [this](#dont-need-two-vms-or-change-other-settings)
## Prerequisites
The script needs terraform and azure cli to run. These can be installed using a packet manager like apt (linux) or using homebrew (mac).

NOTE: These are mac instructions (homebrew -> terraform --> azure cli). Provided as-is. 
```shell
#install homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
## install terraform
brew install terraform
## install az cli
brew install azure-cli
$> az login
## az group create ....
```

installing hashicorp/template on m1 macs
```shell
brew install kreuzwerker/taps/m1-terraform-provider-helper
m1-terraform-provider-helper activate
m1-terraform-provider-helper install hashicorp/template -v v2.2.0
terraform init -upgrade
```

## To use the tfscript
Clone `main` branch. Alternatively use [released packages](https://github.com/amitgupta7/azure-tf-vms/releases)
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
The default script will setup two ubuntu nodes with `10.0.2.21` and `10.0.2.22` private_ip_address in `westus2` azure region, running `ubuntu server 20.04 lts` os version. The default machine size is `Standard_D32s_v3` or the recomended 32 vcores - 128gb ram that securiti.ai recommends for `plus` workloads. 

The script will prompt for an existing `az_subscription_id`, `az_resource_group` and a strong password (`16 chars alpha-num-special-caps`) as `REQUIRED USER INPUT` to provision the resources. 

Note: The `REQUIRED USER INPUT` and other variables like vm os, os disk size, vm-size, subnet cidr etc can also be specified as cli input or local `.tfvars` file. see `var.tf` file for detailed list of variables (and default values) that can be dynamically specified to the script.
```shell
## create a single node cluster
$> tfa -var=vm_map='{"pod1":{"private_ip_address":"10.0.2.21"}}'
## create a two node cluster (default) in eastus2 (instead of default westus2)
tfa -var=location=eastus2
## create a 3 node cluster
$> tfa -var=vm_map='{"pod1":{"private_ip_address":"10.0.2.21"}, "pod2":{"private_ip_address":"10.0.2.22"}, "pod3":{"private_ip_address":"10.0.2.23"}}'
```
Alternatively create a `terraform.tfvars` file to override the variables like location, os-image (offer, sku), vm size and vm_map. e.g.
```hcl
az_subscription_id = "azure-subscription-guid"
az_resource_group  = "existing-resource-group"
vm_size            = "Standard_D8s_v3"
os_publisher       = "RedHat"
os_offer           = "RHEL"
os_sku             = "87-gen2"
azpwd              = "strongPwd"
location           = "eastus2"
vm_map             = {"pod1":{"private_ip_address":"10.0.2.21"},"pod2":{"private_ip_address":"10.0.2.22"}, "pod3":{"private_ip_address":"10.0.2.23"}}
```
## Output (IMPORTANT: please save)
NOTE: The script will output the hostnames and mandatory parameters (for resource cleanup `tfda` command).
```shell
az_resource_group = "your-az-resource-group"
az_subscription_id = "your-az-subscription-guid-value"
hostnames = [
  "azure-tf-vms-pod1.eastus2.cloudapp.azure.com",
  "azure-tf-vms-pod2.eastus2.cloudapp.azure.com",
  "azure-tf-vms-pod3.eastus2.cloudapp.azure.com"
]
ssh_credentials = "azuser/yourPasswordStringHere"
```
## Downloading SAI packages and running a cluster install
Create a new pod and add the download url and license key to your `terraform.tfvars` file. The cloud init will download the packages to `/home/azuser` folder. The script will try and install the cluster. The cloud-init install output can be checked in `/var/log/cloud-init-output.log file`. No clean-up is performed, to allow manually installing the pods (if the script fails). 
```hcl
downloadurl = "provide_installer_tar_url"
licensekey = "provide_license_key"
masterIp = "10.0.2.2"
```
NOTE: In the right conditions this approach could work for demos. However the advisable implementation path would be use the SAI APIs to create the POD instance, download installer and license and check master functioning before registering the worker node. This example also does not run the exhaustive amount of pre-flight checks that are needed to ensure that the install is bullet-proof. Provided as-is (w/o support) for demo/training purposes. 
