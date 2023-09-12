# azure-tf-vms
## Provided as-is (w/o support) 
This example also does not run the exhaustive amount of pre-flight checks that are needed to ensure that the install is bullet-proof. Only for demo/training purposes. The gravity based installer takes about 15 mins to download and 30 minutes to setup. So please be patient as the remote script sets up the cluster. Presently, the script supports only one Master node (and multiple worker nodes). 

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
## install az cli with brew or pip
brew install azure-cli
## pip install azure-cli && echo PATH=\$PATH:\$HOME/.local/bin >> ~/.bashrc && bash -l 
$> az login --use-device-code
## az group create ....
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

## Automatically downloading SAI packages and running a cluster install
Provide the `pod_owner`,`X_TIDENT`, `X_API_Key` and `X_API_Secret` values in your `terraform.tfvars` file. The cloud init will use the APIs to download the packages to `/home/azuser` folder. The script will try and install the cluster. The cloud-init install output can be checked in `/var/log/cloud-init-output.log file`. No clean-up is performed, to allow manually installing the pods (if the script fails). Total runtime for the scripts to add the master and register the worker nodes is about 45 mins. The default `masterIP` is set to `10.0.2.21`.
```hcl
X_API_Secret = "sai_api_secret"
X_API_Key    = "sai_api_key"
X_TIDENT     = "sai_tenant_identifier"
pod_owner    = "sai_tenant_admin_email"
masterIp     = "master_internal_ip_address"
```
NOTE: In the right conditions this approach could work for demos. However, the command `snap install jq` will only work on ubuntu VMs. Please change the same in the `appliance_init.tpl` file before initiating the terraform apply.

## Monitoring Appliance Install
The initial run of `tfaa` starts the install as `nohup`, and exits, while the intaller downloads and runs on the provisioned servers.  

Running `tfaa` again will tail the install log to console if the install is `in-progress`. Press `ctrl+c` to stop the tail. 

In case the install has completed, the output will print the k8s cluster, pods and nodes status.

E.g. When `Installer Status: In-Progress`
```shell
% tfaa
## .....press ctrl+c to exit......
null_resource.install_pod["pod1"] (remote-exec): Connected!
null_resource.install_pod["pod1"] (remote-exec): Existing Installation Lock File Found: /home/azuser/install-status.lock
null_resource.install_pod["pod1"] (remote-exec): Installer Status: In Progress
null_resource.install_pod["pod1"] (remote-exec): Tue Sep 12 20:44:49 UTC        Creating user-supplied Kubernetes resources
null_resource.install_pod["pod1"] (remote-exec): Tue Sep 12 20:44:49 UTC        Create user-supplied Kubernetes resources
null_resource.install_pod["pod1"] (remote-exec): Tue Sep 12 20:44:51 UTC        Executing "/export/azure-tf-vms1-amit-pod1-vm" locally
null_resource.install_pod["pod1"] (remote-exec): Tue Sep 12 20:44:51 UTC        Unpacking application rbac-app:6.1.48
null_resource.install_pod["pod1"] (remote-exec): Tue Sep 12 20:44:51 UTC        Exporting application rbac-app:6.1.48 to local registry
null_resource.install_pod["pod1"] (remote-exec): Tue Sep 12 20:44:51 UTC        Populate Docker registry on master node azure-tf-vms1-amit-pod1-vm
null_resource.install_pod["pod1"] (remote-exec): Tue Sep 12 20:44:52 UTC        Unpacking application dns-app:6.1.3
null_resource.install_pod["pod1"] (remote-exec): Tue Sep 12 20:44:52 UTC        Exporting application dns-app:6.1.3 to local registry
null_resource.install_pod["pod1"] (remote-exec): Tue Sep 12 20:44:54 UTC        Unpacking application bandwagon:6.0.1
null_resource.install_pod["pod1"] (remote-exec): Tue Sep 12 20:44:55 UTC        Exporting application bandwagon:6.0.1 to local registry
null_resource.install_pod["pod1"] (remote-exec): Tue Sep 12 20:44:57 UTC        Unpacking application logging-app:6.0.7
null_resource.install_pod["pod1"] (remote-exec): Tue Sep 12 20:44:58 UTC        Exporting application logging-app:6.0.7 to local registry
null_resource.install_pod["pod1"] (remote-exec): Tue Sep 12 20:45:03 UTC        Unpacking application monitoring-app:6.0.17
```

E.g. When `Installer Status: Completed`
```shell
% tfaa
null_resource.install_pod["pod1"] (remote-exec): Existing Installation Lock File Found: /home/azuser/install-status.lock
null_resource.install_pod["pod1"] (remote-exec): Installer Status: Completed
null_resource.install_pod["pod1"] (remote-exec): Cluster name:          kindgalileo2730
null_resource.install_pod["pod1"] (remote-exec): Cluster status:                active
null_resource.install_pod["pod1"] (remote-exec): Application:           privaci-appliance, version 1.98.1-04p
null_resource.install_pod["pod1"] (remote-exec): Gravity version:       6.1.48 (client) / 6.1.48 (server)
null_resource.install_pod["pod1"] (remote-exec): Join token:            sai123
null_resource.install_pod["pod1"] (remote-exec): Periodic updates:      Not Configured
null_resource.install_pod["pod1"] (remote-exec): Remote support:                Not Configured
null_resource.install_pod["pod1"] (remote-exec): Last completed operation:
null_resource.install_pod["pod1"] (remote-exec):     * 1-node install
null_resource.install_pod["pod1"] (remote-exec):       ID:              ced40d6a-c469-427c-8528-9f04bf6d8fa0
null_resource.install_pod["pod1"] (remote-exec):       Started:         Tue Sep 12 20:40 UTC (27 minutes ago)
null_resource.install_pod["pod1"] (remote-exec):       Completed:       Tue Sep 12 20:41 UTC (27 minutes ago)
null_resource.install_pod["pod1"] (remote-exec): Cluster endpoints:
null_resource.install_pod["pod1"] (remote-exec):     * Authentication gateway:
null_resource.install_pod["pod1"] (remote-exec):         - 10.0.2.21:32009
null_resource.install_pod["pod1"] (remote-exec):     * Cluster management URL:
null_resource.install_pod["pod1"] (remote-exec):         - https://10.0.2.21:32009
null_resource.install_pod["pod1"] (remote-exec): Cluster nodes:
null_resource.install_pod["pod1"] (remote-exec):     Masters:
null_resource.install_pod["pod1"] (remote-exec):         * azure-tf-vms1-amit-pod1-vm / 10.0.2.21 / node
null_resource.install_pod["pod1"] (remote-exec):             Status:            healthy
null_resource.install_pod["pod1"] (remote-exec):             Remote access:     online
null_resource.install_pod["pod1"] (remote-exec): NAME        STATUS   ROLES   AGE   VERSION
null_resource.install_pod["pod1"] (remote-exec): 10.0.2.21   Ready    node    23m   v1.15.12
null_resource.install_pod["pod1"] (remote-exec): NAME                                                    READY   STATUS      RESTARTS   AGE
null_resource.install_pod["pod1"] (remote-exec): kube-metrics-adapter-6b967c7568-zc9fq                   1/1     Running     0          9m51s
null_resource.install_pod["pod1"] (remote-exec): priv-appliance-cargo-message-service-849876d44-c6xjs    1/1     Running     0          9m51s
null_resource.install_pod["pod1"] (remote-exec): priv-appliance-config-controller-8695f8d8d7-fh2nh       1/1     Running     0          9m52s
null_resource.install_pod["pod1"] (remote-exec): priv-appliance-connector-policy-76fc595f6d-vz8tw        3/3     Running     1          9m52s
null_resource.install_pod["pod1"] (remote-exec): priv-appliance-dlq-processor-1694552400-tgp6p           0/1     Completed   0          8m22s
null_resource.install_pod["pod1"] (remote-exec): priv-appliance-download-worker-7cc7569879-dbtbl         3/3     Running     1          9m51s
null_resource.install_pod["pod1"] (remote-exec): priv-appliance-elasticsearch-master-0                   1/1     Running     0          9m51s
null_resource.install_pod["pod1"] (remote-exec): priv-appliance-kafka-worker-6c4978dd76-2mx2v            1/1     Running     0          9m52s
null_resource.install_pod["pod1"] (remote-exec): priv-appliance-monitor-status-nwvlv                     1/1     Running     0          9m52s
null_resource.install_pod["pod1"] (remote-exec): priv-appliance-postgresql-0                             1/1     Running     0          9m52s
null_resource.install_pod["pod1"] (remote-exec): priv-appliance-qos-orchestrator-7d6dc5d598-r8c5g        1/1     Running     3          9m52s
null_resource.install_pod["pod1"] (remote-exec): priv-appliance-ranger-policy-service-7fb86894fb-c6jqf   1/1     Running     0          9m52s
null_resource.install_pod["pod1"] (remote-exec): priv-appliance-redis-master-0                           1/1     Running     0          9m52s
null_resource.install_pod["pod1"] (remote-exec): priv-appliance-redis-metrics-6bdd65c755-8przs           1/1     Running     0          9m52s
null_resource.install_pod["pod1"] (remote-exec): priv-appliance-redis-reaper-54cdbdf894-qstzx            1/1     Running     0          9m52s
null_resource.install_pod["pod1"] (remote-exec): priv-appliance-scheduler-7d8b8788c9-8nqmg               1/1     Running     2          9m52s
null_resource.install_pod["pod1"] (remote-exec): priv-appliance-worker-d8b9f4c78-8xqpz                   1/1     Running     0          9m52s
null_resource.install_pod["pod1"]: Creation complete after 16s [id=4512759690815130263]
```

## EXTRAS: SAI appliance API shell scripts
The `create_sai_appliance.sh` shell script can be used to create an appliance and obtain the download URL. The shell script requires a .env file with SAI API keys. Run the below steps to create a securiti appliance and print the `license_key` and `download_url`. To delete the SAI appliance from the portal, use `delete_appliance.sh` script with the appliance id as argument. 
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
