variable "subscription_id" {
  description = "The Azure subscription ID."
  type        = string
}

variable "resource_group_owner" {
  description = "The owner of the resource group."
  type        = string
}

variable "resource_group_location" {
  type        = string
  default     = "westus3"
  description = "Location of the resource group."
}

variable "project_prefix" {
  description = "Prefix of the resource group name that's combined with a random ID so name is unique in your Azure subscription."
  type        = string
  default     = "raydemo"
}

variable "azure_kubernetes_version" {
  description = "Version of the azure kubernetes"
  default = "1.32"
  type        = string
}

variable "system_node_pool_vm_size" {
  type        = string
  description = "The size of the Virtual Machine."
  default     = "Standard_D2_v2"
}

variable "system_node_pool_node_count" {
  type        = number
  description = "The initial quantity of nodes for the system node pool."
  default     = 1
}

variable "ray_node_pool_vm_size" {
  type        = string
  description = "The size of the Virtual Machine."
  default     = "Standard_D16s_v5"
}

# It is recommended to configure worker node as rayworker count + 1
variable "ray_node_pool_node_count" {
  type        = number
  description = "The initial quantity of node for the workload pools."
  default     = 10
}

variable "ray_second_node_pool_vm_size" {
  type        = string
  description = "The size of the second set of node pool"
  default     = "Standard_D16_v3"
}

variable "ray_second_node_pool_node_count" {
  type        = number
  description = "The initial quantity of node for the workload pools."
  default     = 5
}

variable "username" {
  type        = string
  description = "The admin username for the new cluster."
  default     = "azureadmin"
}

variable "azure_storage_profile" {
  description                    = "Azure CSI drivers storage profile"
  type                           = map(bool)
  default                        = {
    enable_disk_csi_driver       = false
    enable_file_csi_driver       = false
    enable_blob_csi_driver       = true
    enable_snapshot_controller   = false
  }
}

variable "kuberay_version" {
  description                    = "Kuberay version that needs to be installed"
  type                           = string
  default                        = "1.3.0"
}

variable "kuberay_persistent_volume_claim_name" {
  description  = "Name of kubernetes PersistentVolume Claim to deploy rayjob"
  type         = string
  default      = "pvc-blob-results"
}

variable "kuberay_namespace" {
  description  = "Namespace of kubernetes PersistentVolume Claim"
  type         = string
  default      = "default"
}

variable "kuberayjob_storageclass_name" {
  description  = "kubernetes StorageClass name for provisioning persistentvolumeclaims for rayjob"
  type         = string
  default      = "azureblob-fuse-premium"
}

variable "kuberayjob_manifest_path" {
  description = "Kuberay job filepath"
  type        = string
  default     = "../rayjob.yaml"
}
