# Generate random resource group name
resource "random_pet" "rg_name" {
  prefix = var.resource_group_name_prefix
}

resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = random_pet.rg_name.id
}

resource "random_pet" "azurerm_kubernetes_cluster_name" {
  prefix = "cluster"
}

resource "random_pet" "azurerm_kubernetes_cluster_dns_prefix" {
  prefix = "dns"
}

resource "azurerm_kubernetes_cluster" "k8s" {
  location                         = azurerm_resource_group.rg.location
  name                             = random_pet.azurerm_kubernetes_cluster_name.id
  resource_group_name              = azurerm_resource_group.rg.name
  dns_prefix                       = random_pet.azurerm_kubernetes_cluster_dns_prefix.id
  http_application_routing_enabled = true
    
  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name       = "systempool"
    vm_size    = var.system_node_pool_vm_size
    node_count = var.system_node_pool_node_count
    tags = { owner = var.resource_group_owner }
  }

  linux_profile {
    admin_username = var.username

    ssh_key {
      key_data = azapi_resource_action.ssh_public_key_gen.output.publicKey
    }
  }

  network_profile {
    network_plugin    = "azure"
  }

  web_app_routing {
    dns_zone_ids = []
  }
}

resource "azapi_update_resource" "k8s-default-node-pool-systempool-taint" {
  type        = "Microsoft.ContainerService/managedClusters@2024-09-02-preview"
  resource_id = azurerm_kubernetes_cluster.k8s.id
  body = jsonencode({
    properties = {
      agentPoolProfiles = [
        {
          name = "systempool"
          nodeTaints = ["CriticalAddonsOnly=true:NoSchedule"]
        }
      ]
    }
  })

  depends_on = [azurerm_kubernetes_cluster.k8s]
}

resource "azurerm_kubernetes_cluster_node_pool" "workload" {
  name                  = "ray"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.k8s.id
  vm_size               = var.ray_node_pool_vm_size
  node_count            = 4
}