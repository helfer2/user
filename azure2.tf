resource "azurerm_resource_group" "rg" {
  name     = "user25-final"
  location = "koreasouth"
}

variable "application_port" {
   description = "The port that you want to expose to the external load balancer"
   default     = 80
}
resource "azurerm_network_security_group" "secGroup" {
    name = "secGroupuser25final"
    location = "koreasouth"
    resource_group_name ="${azurerm_resource_group.rg.name}"

    security_rule {
        name ="SSH"
        priority = "1001"
        direction = "Inbound"
        access = "Allow"
        protocol = "Tcp"
        source_port_range = "*"
        destination_port_range = "22"
        source_address_prefix = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name = "HTTP"
        priority = "2001"
        direction = "Inbound"
        access = "Allow"
        protocol = "Tcp"
        source_port_range = "*"
        destination_port_range = "80"
        source_address_prefix = "*"
        destination_address_prefix = "*"
    }
}

resource "azurerm_virtual_network" "vnetwork" {
    name = "user25final"
    address_space = ["25.0.0.0/16"]
    location = "koreasouth"
    resource_group_name = "${azurerm_resource_group.rg.name}"
    
}
resource "azurerm_subnet" "mysubnet" {
    name = "MySubnetuser25final"
    resource_group_name = "${azurerm_resource_group.rg.name}"
    virtual_network_name = "${azurerm_virtual_network.vnetwork.name}"
    network_security_group_id = "${azurerm_network_security_group.secGroup.id}"
    address_prefix = "25.0.1.0/24"
}
resource "azurerm_public_ip" "publicdomainip" {
 name                         = "domainipuser25final"
 location                     = "koreasouth"
 resource_group_name          = "${azurerm_resource_group.rg.name}"
 allocation_method            = "Static"
 domain_name_label            = "user25finalskcncazureip"
}

resource "azurerm_public_ip" "rdpip" {
    name = "rdpipuser25final${count.index}"
    location = "koreasouth"
    resource_group_name = "${azurerm_resource_group.rg.name}"
    allocation_method = "Dynamic"
    count = 2
}

resource "azurerm_lb" "lb" {
  resource_group_name = "${azurerm_resource_group.rg.name}"
  name                = "user25loadbalfinal"
  location            = "koreasouth"
  
  frontend_ip_configuration {
    name                 = "LoadBalancerFrontEnd"
    public_ip_address_id = "${azurerm_public_ip.publicdomainip.id}"
  }
}

resource "azurerm_lb_backend_address_pool" "bp" {
    resource_group_name = "${azurerm_resource_group.rg.name}"
    loadbalancer_id     = "${azurerm_lb.lb.id}"
    name                = "BackendPooluser25final"
}

resource "azurerm_network_interface_backend_address_pool_association" "bpAS" {
  count = 2
  network_interface_id = "${element(azurerm_network_interface.nic.*.id, count.index)}"
  ip_configuration_name   = "ipconfig${count.index}"														 
  backend_address_pool_id = "${azurerm_lb_backend_address_pool.bp.id}"
}

resource "azurerm_lb_probe" "lb_probe" {
  resource_group_name = "${azurerm_resource_group.rg.name}"															  
  loadbalancer_id     = "${azurerm_lb.lb.id}"
  name                = "user25tcpProbefinal"
  protocol            = "tcp"
  port                = 80
  interval_in_seconds = 5
  number_of_probes    = 2									 
}

resource "azurerm_lb_rule" "lb_rule" {								
  resource_group_name            = "${azurerm_resource_group.rg.name}"
  loadbalancer_id                = "${azurerm_lb.lb.id}"
  name                           = "user25LBRulefinal"
  protocol                       = "tcp"
  frontend_port                  = "${var.application_port}"
  backend_port                   = "${var.application_port}"
  frontend_ip_configuration_name = "LoadBalancerFrontEnd"
  enable_floating_ip             = false
  backend_address_pool_id        = "${azurerm_lb_backend_address_pool.bp.id}"
  idle_timeout_in_minutes        = 5
  probe_id                       = "${azurerm_lb_probe.lb_probe.id}"
  depends_on                     = ["azurerm_lb_probe.lb_probe"]
}

resource "azurerm_network_interface" "nic" {
  name                = "user25finalnic${count.index}"
  location            = "koreasouth"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  network_security_group_id = "${azurerm_network_security_group.secGroup.id}"  
  count               = 2

  ip_configuration {
    name                                    = "ipconfig${count.index}"
    subnet_id                               = "${azurerm_subnet.mysubnet.id}"
    private_ip_address_allocation           = "Dynamic"    
    public_ip_address_id = "${length(azurerm_public_ip.rdpip.*.id) > 0 ? element(concat(azurerm_public_ip.rdpip.*.id, list("")), count.index) : ""}"	
  }
}

resource "azurerm_availability_set" "avset" {
  name                         = "avsetuser25final"
  location                     = "koreasouth"
  resource_group_name          = "${azurerm_resource_group.rg.name}"
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true
}

resource "azurerm_virtual_machine" "vm" {
  name                  = "user25vmfinal${count.index}"
  location              = "koreasouth"
  resource_group_name   = "${azurerm_resource_group.rg.name}"
  availability_set_id   = "${azurerm_availability_set.avset.id}"
  network_interface_ids = ["${element(azurerm_network_interface.nic.*.id, count.index)}"]
  vm_size = "Standard_D1_v2"
  count = 2
  storage_image_reference {
        publisher = "RedHat"
        offer     = "RHEL"
        sku       = "7.4"
        version   = "latest"
    }  
  storage_os_disk {
        name = "user25finalosdisk${count.index}"
        caching = "ReadWrite"
        create_option = "FromImage"
        managed_disk_type = "Standard_LRS"
  }

  os_profile {
        computer_name = "user25vmfinal${count.index}"
        admin_username = "azureuser"
        admin_password= "Passw0rd"		
  }
  os_profile_linux_config {
        disable_password_authentication = false											 
  }
}
