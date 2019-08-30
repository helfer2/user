resource "random_id" "server" {
  keepers = {
    azi_id = 1
  }
  byte_length = 8
}

resource "azurerm_traffic_manager_profile" "interprovider" {
  name                   = "user25trafficmanager"
  resource_group_name    = "user25-final"
  traffic_routing_method = "Weighted"

  dns_config {
    relative_name = "${random_id.server.hex}"
    ttl           = 30
  }

  monitor_config {
    protocol = "http"
    port     = 80
    path     = "/"
  }
}

resource "azurerm_traffic_manager_endpoint" "azureLB" {
  name                = "first"
  resource_group_name = "user25-final"
  profile_name        = "${azurerm_traffic_manager_profile.interprovider.name}"
  target              = "user25finalskcncazureip.koreasouth.cloudapp.azure.com"
  type                = "externalEndpoints"
  weight              = 1
}

resource "azurerm_traffic_manager_endpoint" "awsLB" {
  name                = "second"
  resource_group_name = "user25-final"
  profile_name        = "${azurerm_traffic_manager_profile.interprovider.name}"
  target              = "albuser25-687662138.ap-northeast-1.elb.amazonaws.com"
  type                = "externalEndpoints"
  weight              = 2
}
