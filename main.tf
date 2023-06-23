terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.61.0"
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

  custom_data = base64encode(data.template_file.cloud-init[each.key].rendered)

}

data "template_file" "cloud-init" {
  for_each              = var.vm_map
  template = file("appliance_init.tpl")
  vars = {
    downloadurl = var.downloadurl
    license     = var.licensekey
    privatePodIp = each.value["private_ip_address"]
    nodeType     = each.value["role"]
    masterIp = var.masterIp
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