resource "random_string" "suffix" {
  length = 6
  special = false
  upper = false
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.project_prefix}-${random_string.suffix.result}"
  location = var.location

  tags = {
    owner = var.resource_group_owner
  }
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azapi_resource" "aks_auto" {
  type      = "Microsoft.ContainerService/managedClusters@2024-06-02-preview"
  name      = "aks-${var.project_prefix}-${random_string.suffix.result}"
  parent_id = azurerm_resource_group.rg.id
  location  = var.location
  tags     = azurerm_resource_group.rg.tags
  
  body = jsonencode({

    properties = {
      kubernetesVersion = "1.31"
      nodeResourceGroup = "MC-aks-${var.project_prefix}-${random_string.suffix.result}"
      agentPoolProfiles = [
        {
          name    = "systempool"
          count   = var.system_node_pool_node_count
          vmSize  = var.system_node_pool_vm_size
          tags    = { owner = var.resource_group_owner }
          mode    = "System"
          osType  = "Linux"
          osSKU   = "AzureLinux"
          osDiskSizeGB = 64
          enableAutoScaling = false
        }
      ]
      linuxProfile = {
        adminUsername = var.username
        ssh = {
          publicKeys = [
            {
              keyData = tls_private_key.ssh_key.public_key_openssh
            }
          ]
        }
      }

      azureMonitorProfile = {
        metrics = {
          enabled = true
          kubeStateMetrics = {
            metricAnnotationsAllowList = var.ksm_allowed_annotations
            metricLabelsAllowlist = var.ksm_allowed_labels
          }
        }
      }
    }

    identity = {
      type = "SystemAssigned"
    }

    sku = {
      name     = "Automatic"
      tier    = "Standard"
    }
  })
}

resource "null_resource" "wait_for_aks" {
  depends_on = [azapi_resource.aks_auto]

  provisioner "local-exec" {
    command = <<EOT
      max_retries=10
      retries=0
      while [ "$(az aks show --resource-group ${azurerm_resource_group.rg.name} --name ${azapi_resource.aks_auto.name} --query "provisioningState" -o tsv)" != "Succeeded" ]; do
        if [ $retries -ge $max_retries ]; then
          echo "Max retries exceeded. Exiting..."
          exit 1
        fi
        echo "Waiting for AKS cluster to be fully provisioned... (Attempt: $((retries+1)))"
        retries=$((retries+1))
        sleep 30
      done
    EOT
  }
}

resource "azapi_update_resource" "k8s-default-node-pool-systempool-taint" {
  type        = "Microsoft.ContainerService/managedClusters@2024-06-02-preview"
  resource_id = azapi_resource.aks_auto.id
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

  depends_on = [null_resource.wait_for_aks]
}

resource "azurerm_kubernetes_cluster_node_pool" "workload" {
  name                  = "ray"
  kubernetes_cluster_id = azapi_resource.aks_auto.id
  vm_size               = var.ray_node_pool_vm_size
  node_count            = 4
  os_type               = "Linux"
  os_sku                = "AzureLinux" 
  os_disk_type          = "Ephemeral"
  mode                  = "User"

  depends_on = [azapi_update_resource.k8s-default-node-pool-systempool-taint]
}

resource "azurerm_log_analytics_workspace" "log_analytics" {
  name                = "law-${var.project_prefix}-${random_string.suffix.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = {
    owner = var.resource_group_owner
  }
}

resource "azurerm_monitor_workspace" "amw" {
  name                = "amon-${var.project_prefix}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

resource "azurerm_monitor_data_collection_endpoint" "prom_endpoint" {
  name                = "prom-${var.project_prefix}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  kind                = "Linux"
}

resource "azurerm_monitor_data_collection_rule" "azprom_dcr" {
  name                        = "promdcr-${var.project_prefix}-${random_string.suffix.result}"
  resource_group_name         = azurerm_resource_group.rg.name
  location                    = azurerm_resource_group.rg.location
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.prom_endpoint.id

  data_sources {
    prometheus_forwarder {
      name    = "PrometheusDataSource"
      streams = ["Microsoft-PrometheusMetrics"]
    }
  }

  destinations {
    monitor_account {
      monitor_account_id = azurerm_monitor_workspace.amw.id
      name               = azurerm_monitor_workspace.amw.name
    }
  }

  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = [azurerm_monitor_workspace.amw.name]
  }
}

# associate to a Data Collection Rule
resource "azurerm_monitor_data_collection_rule_association" "example_dcr_to_aks" {
  name                    = "dcr-${azapi_resource.aks_auto.name}"
  target_resource_id      = azapi_resource.aks_auto.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.azprom_dcr.id
}

# associate to a Data Collection Endpoint
resource "azurerm_monitor_data_collection_rule_association" "example_dce_to_aks" {
  target_resource_id          = azapi_resource.aks_auto.id
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.prom_endpoint.id
}

# add managed grafana
resource "azurerm_dashboard_grafana" "graf" {
  name                = "graf-${var.project_prefix}-${random_string.suffix.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  api_key_enabled     = true
  grafana_major_version = "11"

  identity {
    type = "SystemAssigned"
  }

  azure_monitor_workspace_integrations {
    resource_id = azurerm_monitor_workspace.amw.id
  }
}

resource "azurerm_role_assignment" "graf_role" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_dashboard_grafana.graf.identity[0].principal_id
}


data "azurerm_client_config" "current" {}