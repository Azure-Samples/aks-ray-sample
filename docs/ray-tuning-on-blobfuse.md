# Run a Kuberay tuning job on AKS with Azure Blob Storage and Blobfuse

In this article, you will tune the GPT-2 large model using KubeRay, which will save the final model and checkpoints to an Azure Blob Storage account.

## Prerequisites
An AKS cluster with 10 virtual machines. To create an AKS cluster with 9 Standard_D16d_v5 VMs and 1 Standard_D32d_v5 VM, run the following commands:

```azurecli-interactive
    az aks create --resource-group myResourceGroup --name myAKSCluster --node-count 9 --node-vm-size Standard_D16d_v5 --generate-ssh-keys
    az aks nodepool add --resource-group myResourceGroup --cluster-name myAKSCluster --name nodepool2 --node-count 1 --node-vm-size Standard_D32d_v5
```

## Setup storage for the tuning job

1. Create a Storage Account as described [here](https://learn.microsoft.com/en-us/azure/storage/common/storage-account-create?tabs=azure-portal).

2. Create a container in that storage account as described [here](https://learn.microsoft.com/en-us/azure/storage/blobs/blob-containers-portal#create-a-container)

3. Enable Azure Blob CSI driver on the AKS cluster as described [here](https://learn.microsoft.com/en-us/azure/aks/azure-blob-csi?tabs=NFS#enable-csi-driver-on-a-new-or-existing-aks-cluster).

4. Mount Azure Blob Storage in AKS using the Blob CSI driver with managed identity. Follow the steps [here](https://github.com/kubernetes-sigs/blob-csi-driver/tree/master/deploy/example/blobfuse-mi#mount-azure-blob-storage-with-managed-identity) to create a Managed Identity and assign the Storage Blob Data Contributor role. 

## Setup the AKS cluster and your local machine

1. Install [KubeRay](https://docs.ray.io/en/latest/cluster/kubernetes/getting-started/kuberay-operator-installation.html#step-2-install-kuberay-operator) operator on your AKS cluster.

    ```bash
    helm repo add kuberay https://ray-project.github.io/kuberay-helm/
    helm repo update
    helm install kuberay-operator kuberay/kuberay-operator --version 1.3.0
    ```

2. Edit the pv.yaml file in the sample-tuning-setup directory, and update the values for RESOURCE_GROUP_NAME, STORAGE_ACCOUNT_NAME, and CONTAINER_NAME.

3. Update the MANAGED_IDENTITY_CLIENT_ID in pv.yaml and storageclass.yaml to the client ID of the Managed Identity that now has access to your storage account. You can find the client ID by navigating to the Azure portal, selecting your Managed Identity, and copying the client ID from the 'Overview' section.

4. Apply all the YAML files located in the sample-tuning-setup directory

    ```bash
    kubectl apply -f sample-tuning-setup/storageclass.yaml
    kubectl apply -f sample-tuning-setup/pv.yaml
    kubectl apply -f sample-tuning-setup/pvc.yaml
    kubectl apply -f sample-tuning-setup/rayjob.yaml
    ```

    After a moment, you should be able to see the Ray pods running on the cluster by running the following command:

    ```bash
    kubectl get pods
    ```

    This should also start the tuning job in a pod that starts with name "rayjob-tune-gpt2"

5. The status of the job can be tracked by tracking the logs of the rayjob-tune-gpt2 pod.

    ```bash
    kubectl logs <rayjob_pod_name> -f
    ```

5. Another way to track the status of the job is from the ray dashboard.

    Find the service name of the ray job using the below command

    ```bash
    kubectl get services | grep rayjob-tune-gpt2
    ```

    Open a terminal window and enable port-forwarding for the Ray service to access Ray locally.

    ```bash
    kubectl port-forward services/<rayjob_service_name> 8265:8265
    ```

    Open "http://localhost:8265/" in any browser which should load the dashboard for monitoring the ray job.

Once the run is complete, you will find the final model and checkpoint files in your blob container.



