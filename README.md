# azure-tf-vms
## Provided as-is (w/o support) 
This example also does not run the exhaustive amount of pre-flight checks that are needed to ensure that the install is bullet-proof. Only for demo/training purposes. 

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

installing hashicorp/template on m1 macs (ignore otherwise).
```shell
$> brew install kreuzwerker/taps/m1-terraform-provider-helper
$> m1-terraform-provider-helper activate
$> m1-terraform-provider-helper install hashicorp/template -v v2.2.0
$> terraform init -upgrade
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
$> tfa -var=vm_map='{"pod1":{"private_ip_address":"10.0.2.21", "role":"master"}}'
## create a two node cluster (default) in eastus2 (instead of default westus2)
tfa -var=location=eastus2
## create a 3 node cluster
$> tfa -var=vm_map='{"pod1":{"private_ip_address":"10.0.2.21", "role":"master"}, "pod2":{"private_ip_address":"10.0.2.22", "role":"worker"}, "pod3":{"private_ip_address":"10.0.2.23", "role":"worker"}}'
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
vm_map             = {"pod1":{"private_ip_address":"10.0.2.21", role = "master"},"pod2":{"private_ip_address":"10.0.2.22", role = "worker"}, "pod3":{"private_ip_address":"10.0.2.23", role = "worker"}}
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
## Creating SAI appliance and obtain license and download URL
A new SAI appliance needs to be created in the securiti portal for this script to automatically install and register the POD. Alternatively, the `create_sai_appliance.sh` shell script can be used to create an appliance and obtain the download URL. The shell script requires a .env file with SAI API keys. Run the below steps to create a securiti appliance and print the `license_key` and `download_url` for [next section](#downloading-sai-packages-and-running-a-cluster-install). To delete the SAI appliance from the portal, use `delete_appliance.sh` script with the appliance id as argument. 
```shell 
$> cat sai_api_keys.env
X_API_Secret="api-secret-here"
X_API_Key="api-key-here"
X_TIDENT="sai-tenantId-here"
$> mv sai_api_keys.env .env
$> sh create_sai_appliance.sh
{
  "appliance_name": "localtest-5923",
  "appliance_id": "8a384ab0-d24d-4196-93de-3670207020e4",
  "license": "license_key"
}
{
  "download_url": "installer_tar_url"
}
{
  "appliance_diagnostics_script_url": "diagnostics_script_url"
}
$> sh delete_appliance.sh 8a384ab0-d24d-4196-93de-3670207020e4
{
  "status": 0,
  "message": "Deletion successful"
}
```
## Downloading SAI packages and running a cluster install
Provide the `pod_owner`,`X_TIDENT`, `X_API_Key` and `X_API_Secret` values in your `terraform.tfvars` file. The cloud init will use the APIs to download the packages to `/home/azuser` folder. The script will try and install the cluster. The cloud-init install output can be checked in `/var/log/cloud-init-output.log file`. No clean-up is performed, to allow manually installing the pods (if the script fails). Total runtime for the scripts to add the master and register the worker nodes is about 45 mins. The default `masterIP` is set to `10.0.2.21`.
```hcl
X_API_Secret = "sai_api_secret"
X_API_Key    = "sai_api_key"
X_TIDENT     = "sai_tenant_identifier"
pod_owner    = "sai_tenant_admin_email"
masterIp     = "master_internal_ip_address"
```
NOTE: In the right conditions this approach could work for demos. However, the command `snap install jq` will only work on ubuntu VMs. Please change the same in the `appliance_init.tpl` file before initiating the terraform apply.
