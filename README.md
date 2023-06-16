# azure-tf-vms
Prerequisites
```shell
## install terraform
## install az cli
$> az login
## az group create 
```

To use the tfscript
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
Default creates two pod nodes. To override pass the vm map in cli
```shell
## creaet a single node cluster
tfa -var=vm_map='{"pod1":{"private_ip_address":"10.0.2.21"}}'
## creaet a two node cluster (default)
tfa
## create a 3 node cluster
$> tfa -var=vm_map='{"pod1":{"private_ip_address":"10.0.2.21"}, "pod2":{"private_ip_address":"10.0.2.22"}, "pod3":{"private_ip_address":"10.0.2.23"}}'
```
