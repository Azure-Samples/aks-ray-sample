# Generate random suffix for unique naming conventions
resource "random_string" "suffix" {
  length = 6
  special = false
  upper = false
}

# Resource group for AKS
resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.project_prefix}-${random_string.suffix.result}"
  location = var.resource_group_location
}

data "azurerm_client_config" "current" {}

# Configure monitor workspace
resource "azurerm_monitor_workspace" "amw" {
  name                = "amon-${var.project_prefix}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags = {
    owner = var.resource_group_owner
  }
}

# Configuration for AKS cluster
resource "azurerm_kubernetes_cluster" "aks" {
  location            = azurerm_resource_group.rg.location
  name                = "cluster-${var.project_prefix}-${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  kubernetes_version  = var.azure_kubernetes_version

  # DNS prefix for the cluster API
  dns_prefix   = "demo-${var.project_prefix}"

  # Default Node pool configuration
  default_node_pool {
    name            = "systempool"
    vm_size         = var.system_nodepool_vm_size
    node_count      = var.system_nodepool_node_count
    tags = { owner  = var.resource_group_owner}
    type = "VirtualMachineScaleSets"
  }

  # Use Azure CNI networking required for network policies
  network_profile {
    network_plugin = "azure"
    network_policy = "azure"
    load_balancer_sku = "standard"
  }

  linux_profile {
    admin_username = var.username
    ssh_key {
      key_data = azapi_resource_action.ssh_public_key_gen.output.publicKey
    }
  }

  # AKS uses a managed identity
  identity {
    type = "SystemAssigned"
  }

  # Configuration for Azure CSI drivers
  storage_profile {
    disk_driver_enabled         = var.azure_storage_profile["enable_disk_csi_driver"]
    file_driver_enabled         = var.azure_storage_profile["enable_file_csi_driver"]
    blob_driver_enabled         = var.azure_storage_profile["enable_blob_csi_driver"]
    snapshot_controller_enabled = var.azure_storage_profile["enable_snapshot_controller"]
  }

  # Enable Managed Prometheus
  monitor_metrics {}
}

# Wait for Kubernetes cluster
resource "null_resource" "wait_for_aks" {
  depends_on = [azurerm_kubernetes_cluster.aks]

  provisioner "local-exec" {
    command = <<EOT
      max_retries=20
      retries=0
      while [ "$(az aks show --resource-group ${azurerm_resource_group.rg.name} --name ${azurerm_kubernetes_cluster.aks.name} --query "provisioningState" -o tsv)" != "Succeeded" ]; do
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

resource "azapi_update_resource" "aks-default-node-pool-systempool-taint" {
  type        = "Microsoft.ContainerService/managedClusters@2024-09-02-preview"
  resource_id = azurerm_kubernetes_cluster.aks.id
  body = jsonencode({
    properties = {
      agentPoolProfiles = [
        {
          name       = "systempool"
          nodeTaints = ["CriticalAddonsOnly=true:NoSchedule"]
        }
      ]
    }
  })

  depends_on = [null_resource.wait_for_aks]
}


resource "azurerm_kubernetes_cluster_node_pool" "workload1" {
  name                  = "nodepool1"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = var.ray_nodepool1_vm_size
  node_count            = var.ray_nodepool1_node_count

  depends_on = [azapi_update_resource.aks-default-node-pool-systempool-taint]
}

resource "azurerm_kubernetes_cluster_node_pool" "workload2" {
  count                 = var.ray_nodepool2_node_count > 0 ? 1 : 0
  name                  = "nodepool2"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = var.ray_nodepool2_vm_size
  node_count            = var.ray_nodepool2_node_count

  depends_on = [azapi_update_resource.aks-default-node-pool-systempool-taint]
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
resource "azurerm_monitor_data_collection_rule_association" "associate_dcr_to_aks" {
  name                    = "dcr-${azurerm_kubernetes_cluster.aks.name}"
  target_resource_id      = azurerm_kubernetes_cluster.aks.id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.azprom_dcr.id
}

# associate to a Data Collection Endpoint
resource "azurerm_monitor_data_collection_rule_association" "associate_dce_to_aks" {
  target_resource_id          = azurerm_kubernetes_cluster.aks.id
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.prom_endpoint.id
}

# Add managed grafana
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

# Assign role to resource group
resource "azurerm_role_assignment" "graf_role" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_dashboard_grafana.graf.identity[0].principal_id
}

resource "azurerm_role_assignment" "grafana_admin_self" {
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Grafana Admin"
  scope                = azurerm_dashboard_grafana.graf.id
}

# Extract the Kubeconfig info from AKS data source
locals {
  host = azurerm_kubernetes_cluster.aks.kube_config[0].host
  client_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_certificate)
  client_key         = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.aks.kube_config[0].cluster_ca_certificate)
}

resource "helm_release" "nginx_ingress" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = var.kuberay_namespace
  create_namespace = true
  depends_on = [azurerm_kubernetes_cluster_node_pool.workload1]
}

# Create Kuberay namespace and deploy Kuberay via Helm chart
resource "helm_release" "kuberay" {
  name             = "kuberay-operator"
  repository       = "https://ray-project.github.io/kuberay-helm"
  chart            = "kuberay-operator"
  namespace        = var.kuberay_namespace
  create_namespace = true

  version          = var.kuberay_version

  # Default values install cluster-scoped operator.
  # To restrict operator to one namespace, you could set:
  # set {
  #   name  = "singleNamespaceInstall"
  #   value = "true"
  # }
  # set {
  #   name  = "watchNamespace"
  #   value = "kuberay"
  # }
  depends_on = [azurerm_kubernetes_cluster_node_pool.workload1]
}

# Provision PersistentVolumeClaim for Rayjob
resource "kubernetes_persistent_volume_claim" "rayjob_pvc" {
  metadata {
    name      = var.kuberay_persistent_volume_claim_name
    namespace = var.kuberay_namespace
  }

  spec {
    access_modes = ["ReadWriteOnce"]
    storage_class_name = var.kuberayjob_storageclass_name
    resources {
      requests = {
        storage = "200Gi"
      }
    }
  }
  depends_on = [helm_release.kuberay]
}

# Deploy Rayjob
resource "kubectl_manifest" "rayjob" {
  yaml_body = file(var.kuberayjob_manifest_path)
  depends_on = [kubernetes_persistent_volume_claim.rayjob_pvc]
}

# Configure to scrape ray metrics
resource "kubectl_manifest" "kuberay_scrape_config" {
  depends_on = [kubectl_manifest.rayjob]
  yaml_body = file(var.kuberay_scrape_config_path)
}
