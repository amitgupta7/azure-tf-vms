# azure-tf-vms
## Provided as-is (w/o support) 
This example also does not run the exhaustive amount of pre-flight checks that are needed to ensure that the install is bullet-proof. Only for demo/training purposes. The k3s based installer takes about 60 seconds mins to download and setup. Presently, the script supports only one Master node (and multiple worker nodes). This setup requires `k3s-based-pod-installer` setting enabled for BOP. For gravity based installer setup, see [release 3.0](https://github.com/amitgupta7/azure-tf-vms/releases/tag/3.0)  

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
The initial run of `tfaa` starts the install as `nohup`, and exits. The intaller script continues the downloads and runs in background on the provisioned servers. If you would like to run a verbose install, use `tfaa && tfaa`, or running `tfaa` again after the initial install, to print install status depening on the status of the install:
* If the `Installer Status: In-Progress`: Running `tfaa` will tail the install log to console . Press `ctrl+c` to stop the tail. 
* If the `Installer Status: Completed` Running `tfaa` will print the k8s cluster, pods and nodes status.
* If the `Installer Status: Error` Running `tfaa` will print the error and the steps to rerun the installer.
* If the `Installer Status: Error` Running `tfaa  -var=clr_lock=true` will reset the error state to `In-Progress` and rerun the installer as `nohup` in background on the provisioned servers. This feature is `Experimental`, and maynot be adequate to perform a clean-up and fresh install. Run `tfda && tfaa` if `tfaa  -var=clr_lock=true` doesn't work.

E.g. When `Installer Status: In-Progress`
```shell
% tfaa
## .....press ctrl+c to exit......
null_resource.install_pod["pod1"] (remote-exec): [INFO]  Awaiting default/statefulset/priv-appliance-postgresql to be ready
null_resource.install_pod["pod1"] (remote-exec): Waiting for 1 pods to be ready...
null_resource.install_pod["pod2"] (remote-exec): [INFO]  Validating inputs
null_resource.install_pod["pod2"] (remote-exec): [INFO]  Done validating inputs
null_resource.install_pod["pod2"] (remote-exec): [INFO]  Downloading installer
null_resource.install_pod["pod1"]: Still creating... [40s elapsed]
null_resource.install_pod["pod2"]: Still creating... [40s elapsed]
null_resource.install_pod["pod2"] (remote-exec): Status: 200
null_resource.install_pod["pod2"] (remote-exec): [INFO]  Done downloading installer
null_resource.install_pod["pod2"] (remote-exec): [WARN]  Skipping installer verification
null_resource.install_pod["pod2"] (remote-exec): [INFO]  Unzipping the installer
null_resource.install_pod["pod2"] (remote-exec): [INFO]  Done unzipping the installer
null_resource.install_pod["pod2"] (remote-exec): [INFO]  Ensuring pre-reqs
null_resource.install_pod["pod2"] (remote-exec): [INFO]  Loading required kernel modules
null_resource.install_pod["pod2"] (remote-exec): [INFO]  Adding kernel module br_netfilter
null_resource.install_pod["pod2"] (remote-exec): [INFO]  Adding kernel module overlay
null_resource.install_pod["pod2"] (remote-exec): [INFO]  Adding kernel module ebtables
null_resource.install_pod["pod2"] (remote-exec): [INFO]  Adding kernel module ebtable_filter
null_resource.install_pod["pod2"] (remote-exec): [INFO]  Adding kernel module iptable_filter
null_resource.install_pod["pod2"] (remote-exec): [INFO]  Adding kernel module iptable_nat
null_resource.install_pod["pod2"] (remote-exec): [INFO]  Done loading required kernel modules
null_resource.install_pod["pod2"] (remote-exec): [INFO]  Setting sysctl configs
null_resource.install_pod["pod2"] (remote-exec): * Applying /etc/sysctl.d/10-console-messages.conf ...
null_resource.install_pod["pod2"] (remote-exec): kernel.printk = 4 4 1 7
null_resource.install_pod["pod2"] (remote-exec): * Applying /etc/sysctl.d/10-ipv6-privacy.conf ...
null_resource.install_pod["pod2"] (remote-exec): net.ipv6.conf.all.use_tempaddr = 2
null_resource.install_pod["pod2"] (remote-exec): net.ipv6.conf.default.use_tempaddr = 2
null_resource.install_pod["pod2"] (remote-exec): * Applying /etc/sysctl.d/10-kernel-hardening.conf ...
null_resource.install_pod["pod2"] (remote-exec): kernel.kptr_restrict = 1
null_resource.install_pod["pod2"] (remote-exec): * Applying /etc/sysctl.d/10-link-restrictions.conf ...
null_resource.install_pod["pod2"] (remote-exec): fs.protected_hardlinks = 1
null_resource.install_pod["pod2"] (remote-exec): fs.protected_symlinks = 1
null_resource.install_pod["pod2"] (remote-exec): * Applying /etc/sysctl.d/10-magic-sysrq.conf ...
null_resource.install_pod["pod2"] (remote-exec): kernel.sysrq = 176
null_resource.install_pod["pod2"] (remote-exec): * Applying /etc/sysctl.d/10-network-security.conf ...
null_resource.install_pod["pod2"] (remote-exec): net.ipv4.conf.default.rp_filter = 2
null_resource.install_pod["pod2"] (remote-exec): net.ipv4.conf.all.rp_filter = 2
null_resource.install_pod["pod2"] (remote-exec): * Applying /etc/sysctl.d/10-ptrace.conf ...
null_resource.install_pod["pod2"] (remote-exec): kernel.yama.ptrace_scope = 1
null_resource.install_pod["pod2"] (remote-exec): * Applying /etc/sysctl.d/10-zeropage.conf ...
null_resource.install_pod["pod2"] (remote-exec): vm.mmap_min_addr = 65536
null_resource.install_pod["pod2"] (remote-exec): * Applying /usr/lib/sysctl.d/50-default.conf ...
null_resource.install_pod["pod2"] (remote-exec): net.ipv4.conf.default.promote_secondaries = 1
null_resource.install_pod["pod2"] (remote-exec): sysctl: setting key "net.ipv4.conf.all.promote_secondaries": Invalid argument
null_resource.install_pod["pod2"] (remote-exec): net.ipv4.ping_group_range = 0 2147483647
```

E.g. When `Installer Status: Completed`
```shell
% tfaa
null_resource.install_pod["pod2"] (remote-exec): Existing Installation Lock File Found: /home/azuser/install-status.lock
null_resource.install_pod["pod2"] (remote-exec): Installer Status: Completed on worker
null_resource.install_pod["pod2"] (remote-exec):      Active: active (running) since Tue 2023-11-21 17:59:56 UTC; 1min 56s ago
null_resource.install_pod["pod2"]: Creation complete after 15s [id=3576704981984554564]
null_resource.install_pod["pod1"] (remote-exec): Connected!
null_resource.install_pod["pod1"] (remote-exec): Existing Installation Lock File Found: /home/azuser/install-status.lock
null_resource.install_pod["pod1"] (remote-exec): Installer Status: Completed on master
null_resource.install_pod["pod1"] (remote-exec): NAME                         STATUS   ROLES                  AGE     VERSION
null_resource.install_pod["pod1"] (remote-exec): azure-tf-vms1-amit-pod2-vm   Ready    <none>                 2m2s    v1.28.2+k3s1
null_resource.install_pod["pod1"] (remote-exec): azure-tf-vms1-amit-pod1-vm   Ready    control-plane,master   3m16s   v1.28.2+k3s1
null_resource.install_pod["pod1"] (remote-exec): NODE-IP     NAME                                                     STATUS
null_resource.install_pod["pod1"] (remote-exec): 10.0.2.22   priv-appliance-prometheus-node-exporter-6knwg            Running
null_resource.install_pod["pod1"] (remote-exec): 10.0.2.22   priv-appliance-monitor-status-24phl                      Running
null_resource.install_pod["pod1"] (remote-exec): 10.0.2.22   priv-appliance-dlq-processor-28343160-r5trg              Succeeded
null_resource.install_pod["pod1"] (remote-exec): 10.0.2.21   priv-appliance-worker-8477c898bd-mlrpr                   Running
null_resource.install_pod["pod1"] (remote-exec): 10.0.2.21   priv-appliance-spark-operator-webhook-init-qhxql         Succeeded
null_resource.install_pod["pod1"] (remote-exec): 10.0.2.21   priv-appliance-scheduler-7bd7f655f5-kg9lk                Running
null_resource.install_pod["pod1"] (remote-exec): 10.0.2.21   priv-appliance-redis-reaper-569dc9d445-xkqw4             Running
null_resource.install_pod["pod1"] (remote-exec): 10.0.2.21   priv-appliance-redis-master-0                            Running
null_resource.install_pod["pod1"] (remote-exec): 10.0.2.21   priv-appliance-ranger-policy-service-6bb4cf8b44-6nwjs    Running
null_resource.install_pod["pod1"] (remote-exec): 10.0.2.21   priv-appliance-qos-orchestrator-58799497d5-wp2tb         Running
null_resource.install_pod["pod1"] (remote-exec): 10.0.2.21   priv-appliance-prometheus-server-56f6cfd864-pbxbf        Running
null_resource.install_pod["pod1"] (remote-exec): 10.0.2.21   priv-appliance-prometheus-pushgateway-7b8cf9df59-xnx25   Running
null_resource.install_pod["pod1"] (remote-exec): 10.0.2.21   priv-appliance-prometheus-node-exporter-whcfp            Running
null_resource.install_pod["pod1"] (remote-exec): 10.0.2.21   priv-appliance-postgresql-0                              Running
null_resource.install_pod["pod1"] (remote-exec): 10.0.2.21   priv-appliance-monitor-status-kdxpq                      Running
null_resource.install_pod["pod1"] (remote-exec): 10.0.2.21   priv-appliance-kafka-worker-7d74875b9d-q2cvd             Running
null_resource.install_pod["pod1"] (remote-exec): 10.0.2.21   priv-appliance-elasticsearch-master-0                    Running
null_resource.install_pod["pod1"] (remote-exec): 10.0.2.21   priv-appliance-connector-policy-557c657d88-wrbzj         Running
null_resource.install_pod["pod1"] (remote-exec): 10.0.2.21   priv-appliance-config-controller-84f974fd89-6d44b        Running
null_resource.install_pod["pod1"] (remote-exec): 10.0.2.21   priv-appliance-cargo-message-service-b98fd497c-dbd4c     Running
null_resource.install_pod["pod1"] (remote-exec): 10.0.2.21   metrics-server-67c658944b-fh5ct                          Running
null_resource.install_pod["pod1"] (remote-exec): 10.0.2.21   local-path-provisioner-84db5d44d9-4s85b                  Running
null_resource.install_pod["pod1"] (remote-exec): 10.0.2.21   kube-metrics-adapter-7d474c59b5-vtbgp                    Running
null_resource.install_pod["pod1"] (remote-exec): 10.0.2.21   coredns-6799fbcd5-g4km9                                  Running
null_resource.install_pod["pod1"] (remote-exec):      Active: active (running) since Tue 2023-11-21 17:58:26 UTC; 3min 32s ago
null_resource.install_pod["pod1"]: Creation complete after 20s [id=5651385936831301419]
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
