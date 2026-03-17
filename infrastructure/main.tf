terraform {
    required_providers {
        azurerm = {
            source = "hashicorp/azurerm"
            version = "4.56.0"
        }
        random = {
            source = "hashicorp/random"
            version = "~> 3.5"
        }
    }
}

provider "azurerm" {
    features {}
}

locals {
    terraform_state_key = "sourcecontrol.tfstate"
}

data "azurerm_client_config" "current" {}

# Generate a random suffix for unique DNS name
resource "random_integer" "suffix" {
    min = 1000
    max = 9999
}

# Create a resource group
resource "azurerm_resource_group" "sourcecontrol" {
    name = "sourcecontrol"
    location = "Canada Central"
    tags = {
        organization = "JUS"
        environment  = "Development"
    }
}

resource "azurerm_key_vault" "sourcecontrol" {
    name                = "sourcecontrolkv${random_integer.suffix.result}"
    location            = azurerm_resource_group.sourcecontrol.location
    resource_group_name = azurerm_resource_group.sourcecontrol.name
    tenant_id           = data.azurerm_client_config.current.tenant_id
    sku_name            = "standard"

    purge_protection_enabled   = false
    soft_delete_retention_days = 7

    access_policy {
        tenant_id = data.azurerm_client_config.current.tenant_id
        object_id = data.azurerm_client_config.current.object_id

        secret_permissions = [
            "Get",
            "List",
            "Set",
            "Delete",
            "Purge",
            "Recover",
        ]
    }
}

resource "azurerm_storage_account" "terraform_state" {
    name                     = "sourcecontroltf${random_integer.suffix.result}"
    resource_group_name      = azurerm_resource_group.sourcecontrol.name
    location                 = azurerm_resource_group.sourcecontrol.location
    account_tier             = "Standard"
    account_replication_type = "LRS"
    min_tls_version          = "TLS1_2"

    blob_properties {
        versioning_enabled = true
    }
}

resource "azurerm_storage_container" "terraform_state" {
    name                  = "tfstate"
    storage_account_id    = azurerm_storage_account.terraform_state.id
    container_access_type = "private"
}

resource "azurerm_role_assignment" "terraform_state_blob_access" {
    scope                = azurerm_storage_account.terraform_state.id
    role_definition_name = "Storage Blob Data Contributor"
    principal_id         = data.azurerm_client_config.current.object_id
}

# Create a virtual machine
resource "azurerm_virtual_network" "sourcecontrol-vnet" {
    name                = "sourcecontrol-vnet"
    address_space       = ["10.0.0.0/16"]
    location            = azurerm_resource_group.sourcecontrol.location
    resource_group_name = azurerm_resource_group.sourcecontrol.name
}

resource "azurerm_subnet" "sourcecontrol-subnet" {
    name                 = "sourcecontrol-subnet"
    resource_group_name  = azurerm_resource_group.sourcecontrol.name
    virtual_network_name = azurerm_virtual_network.sourcecontrol-vnet.name
    address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_public_ip" "sourcecontrol-pip" {
    name                = "sourcecontrol-pip"
    location            = azurerm_resource_group.sourcecontrol.location
    resource_group_name = azurerm_resource_group.sourcecontrol.name
    allocation_method   = "Static"
    sku = "Standard"
    domain_name_label = "justicedatainventory"
}

resource "azurerm_network_security_group" "sourcecontrol-nsg" {
    name                = "sourcecontrol-nsg"
    location            = azurerm_resource_group.sourcecontrol.location
    resource_group_name = azurerm_resource_group.sourcecontrol.name

    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "443"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "HTTP"
        priority                   = 1002
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "HTTP-Alt"
        priority                   = 1003
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "8080"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
  
}

resource "azurerm_network_interface" "sourcecontrol-nic" {
    name                = "sourcecontrol-nic"
    location            = azurerm_resource_group.sourcecontrol.location
    resource_group_name = azurerm_resource_group.sourcecontrol.name

    ip_configuration {
        name                          = "internal"
        subnet_id                     = azurerm_subnet.sourcecontrol-subnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id = azurerm_public_ip.sourcecontrol-pip.id
    }
}

resource "azurerm_network_interface_security_group_association" "sourcecontrol-nic-nsg-association" {
    network_interface_id      = azurerm_network_interface.sourcecontrol-nic.id
    network_security_group_id = azurerm_network_security_group.sourcecontrol-nsg.id
}

resource "azurerm_linux_virtual_machine" "sourcecontrol-vm" {
    name                = "sourcecontrol-vm"
    resource_group_name = azurerm_resource_group.sourcecontrol.name
    location            = azurerm_resource_group.sourcecontrol.location
    size                = "Standard_B2ms"
    admin_username      = "azureuser"
    network_interface_ids = [
        azurerm_network_interface.sourcecontrol-nic.id,
    ]

    admin_ssh_key {
        username   = "azureuser"
        public_key = file("~/.ssh/id_rsa.pub")
    }

    os_disk {
        caching              = "ReadWrite"
        storage_account_type = "Standard_LRS"
    }

    source_image_reference {
      publisher = "Canonical"
      offer = "0001-com-ubuntu-server-jammy"
      sku = "22_04-lts"
      version = "latest"
    }

    disable_password_authentication = true

    custom_data = base64encode(<<-EOF
      #!/bin/bash
      sed -i 's/#Port 22/Port 443/' /etc/ssh/sshd_config
      systemctl restart ssh
    EOF
    )

}

output "public_ip_address" {
  value = azurerm_public_ip.sourcecontrol-pip.ip_address
  description = "The public IP address of the VM"
}

output "dns_name" {
    value = azurerm_public_ip.sourcecontrol-pip.domain_name_label
    description = "The DNS name of the public IP"  
}

output "key_vault_name" {
    value = azurerm_key_vault.sourcecontrol.name
    description = "The Azure Key Vault that stores deployment secrets"
}

output "terraform_state_resource_group_name" {
    value = azurerm_resource_group.sourcecontrol.name
    description = "The resource group that contains the remote OpenTofu state storage"
}

output "terraform_state_storage_account_name" {
    value = azurerm_storage_account.terraform_state.name
    description = "The storage account that stores the remote OpenTofu state"
}

output "terraform_state_container_name" {
    value = azurerm_storage_container.terraform_state.name
    description = "The storage container that stores the remote OpenTofu state"
}

output "terraform_state_key" {
    value = local.terraform_state_key
    description = "The blob name used for the remote OpenTofu state"
}