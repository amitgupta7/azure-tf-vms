# azure-tf-vms
To add terraform shortcuts to shell use below. 
```shell
$> git clone https://github.com/amitgupta7/azure-tf-vms.git
$> cd azure-tf-vms
$> source tfAlias
$> tf init
## provision infra for pods
## provide EXISTING resource group name, azure subscription-id and vm-password on prompt
$> tfaa 
## de-provision 
## provide EXISTING resource group name, azure subscription-id and vm-password on prompt (as above)
$> tfda
```