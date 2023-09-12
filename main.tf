terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.66.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id            = var.az_subscription_id
  skip_provider_registration = true
}

resource "azurerm_virtual_network" "vnet" {
  name                = "${var.az_name_prefix}_pod-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = var.az_resource_group
}

resource "azurerm_subnet" "subnet" {
  name                 = "${var.az_name_prefix}_pod-subnet"
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = var.az_resource_group
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_security_group" "pod_sg" {
  name                = "${var.az_name_prefix}_pods-sg"
  location            = var.location
  resource_group_name = var.az_resource_group

  security_rule {
    name                       = "SSH"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "pod_ip" {
  for_each            = var.vm_map
  name                = "${var.az_name_prefix}_${each.key}_ip"
  location            = var.location
  resource_group_name = var.az_resource_group
  allocation_method   = "Dynamic"
  domain_name_label   = "${var.az_name_prefix}-${each.key}"
}

resource "azurerm_network_interface" "pod_nic" {
  for_each            = var.vm_map
  name                = "${var.az_name_prefix}_${each.key}_nic"
  location            = var.location
  resource_group_name = var.az_resource_group
  ip_configuration {
    name                          = "${var.az_name_prefix}_${each.key}_ipconfig"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = each.value["private_ip_address"]
    public_ip_address_id          = azurerm_public_ip.pod_ip[each.key].id
  }
}

resource "azurerm_network_interface_security_group_association" "nsg" {
  for_each                  = var.vm_map
  network_interface_id      = azurerm_network_interface.pod_nic[each.key].id
  network_security_group_id = azurerm_network_security_group.pod_sg.id
}


resource "azurerm_linux_virtual_machine" "podvms" {
  for_each              = var.vm_map
  name                  = "${var.az_name_prefix}-${each.key}-vm"
  network_interface_ids = [azurerm_network_interface.pod_nic[each.key].id]
  //variables
  location            = var.location
  resource_group_name = var.az_resource_group
  size                = var.vm_size
  os_disk {
    name                 = "${var.az_name_prefix}-${each.key}-os-disk"
    disk_size_gb         = var.os_disk_size_in_gb
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  source_image_reference {
    publisher = var.os_publisher
    offer     = var.os_offer
    sku       = var.os_sku
    version   = var.os_version
  }
  admin_username                  = var.azuser
  admin_password                  = var.azpwd
  disable_password_authentication = false
}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "example" {
  for_each              = var.vm_map
  virtual_machine_id    = azurerm_linux_virtual_machine.podvms[each.key].id
  location              = var.location
  enabled            = true

  daily_recurrence_time = "1100"
  timezone              = "Pacific Standard Time"

  notification_settings {
    enabled         = false
  }
}

resource "null_resource" "install_pod" {
    triggers = {
    build_number = "${timestamp()}"
  }
  for_each = var.vm_map
  depends_on = [azurerm_linux_virtual_machine.podvms]
  connection {
    type     = "ssh"
    user     = var.azuser
    password = var.azpwd
    host = azurerm_public_ip.pod_ip[each.key].fqdn
  }
  provisioner "file" {
    source = "appliance_init.tpl"
    destination = "/home/${var.azuser}/appliance_init.tpl"
  }

    provisioner "file" {
    source = "install_status.sh"
    destination = "/home/${var.azuser}/install_status.sh"
  }

  provisioner "remote-exec" {
    inline = ["sudo sh /home/${var.azuser}/install_status.sh /home/${var.azuser}/install-status.lock", 
    "[ ! -f /home/${var.azuser}/install-status.lock ] && nohup sudo sh /home/${var.azuser}/appliance_init.tpl -n ${each.value["role"]} -o ${var.pod_owner} -r ${var.masterIp} -k ${var.X_API_Key} -s ${var.X_API_Secret} -t ${var.X_TIDENT} -i ${each.value["private_ip_address"]} > /home/${var.azuser}/appliance_init.out 2>&1 &", 
    "sleep 1" ]
  }

}


output "hostnames" {
  value = values(azurerm_public_ip.pod_ip).*.fqdn
}

output "az_subscription_id" {
  value = var.az_subscription_id
}

output "az_resource_group" {
  value = var.az_resource_group
}

output "ssh_credentials" {
  value = "${var.azuser}/${var.azpwd}"
}