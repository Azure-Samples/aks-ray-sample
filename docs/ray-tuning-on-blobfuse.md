# Run a Kuberay tuning job on AKS with Azure Blob Storage and Blobfuse

In this article, you will tune the GPT-2 large model using KubeRay, which will save the final model and checkpoints to an Azure Blob Storage account.

## Prerequisites
- Install Azure CLI by following [azure-cli](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?view=azure-cli-latest&pivots=apt) doc.
- Install terraform command line tool by following [installation](https://developer.hashicorp.com/terraform/install) doc.


### Quickstart
1. Clone the repository https://github.com/Azure-Samples/aks-ray-sample on to your local machine.
2. Navigate to the directory you cloned the repository and then navigate to sample-tunning-setup/terraform.
3. Enable execute permissions on the `deploy.sh` script by running `chmod +x deploy.sh`.
4. Run the `deploy.sh` script by running `./deploy.sh`. This script will deploy the AKS cluster, install the KubeRay operator then submit a training job pointing to azure blob storage to run on the AKS cluster.

   Once the script finish execution, then open the URL displayed in the final line (see the example below for the script's last few lines).
   ```sh
   ...
   ...
   ...
   Merged "cluster-raydemo-gzumb2" as current context in /home/mittas/.kube/config
   Current Kubernetes Context: cluster-raydemo-gzumb2
   NAME                                 STATUS   ROLES    AGE     VERSION
   aks-nodepool1-13403768-vmss000000    Ready    <none>   3m4s    v1.32.4
   aks-nodepool1-13403768-vmss000001    Ready    <none>   2m40s   v1.32.4
   aks-nodepool1-13403768-vmss000002    Ready    <none>   2m39s   v1.32.4
   aks-nodepool1-13403768-vmss000003    Ready    <none>   3m9s    v1.32.4
   aks-nodepool1-13403768-vmss000004    Ready    <none>   2m46s   v1.32.4
   aks-nodepool1-13403768-vmss000005    Ready    <none>   2m42s   v1.32.4
   aks-systempool-37389976-vmss000000   Ready    <none>   10m     v1.32.4
   NAME                                                         READY   STATUS              RESTARTS   AGE
   ingress-nginx-controller-68547f7c99-hzl6t                    1/1     Running             0          75s
   kuberay-operator-b568bb49f-nd9qn                             1/1     Running             0          97s
   rayjob-tune-gpt2-raycluster-bd7lt-head-kg4vl                 0/1     ContainerCreating   0          46s
   rayjob-tune-gpt2-raycluster-bd7lt-large-group-worker-b7nfh   0/1     Init:0/2            0          46s
   rayjob-tune-gpt2-raycluster-bd7lt-large-group-worker-lgd2m   0/1     Init:0/2            0          46s
   rayjob-tune-gpt2-raycluster-bd7lt-large-group-worker-s976k   0/1     Init:0/2            0          46s
   rayjob-tune-gpt2-raycluster-bd7lt-large-group-worker-t4dg6   0/1     Init:0/2            0          46s
   rayjob-tune-gpt2-raycluster-bd7lt-large-group-worker-vh4gz   0/1     Init:0/2            0          46s
   Ray Job Status: Initializing
   service/ray-dash exposed
   ingress.networking.k8s.io/ray-dash created
   KubeRay Dashboard URL(progress of rayjob can be viewed here): http://4.236.5.17/
   Waiting for Kuberay job completion
   Job Status: Complete
   To view the final model and checkpoint files go to Azure portal
   Navigate through ResourceGroup MC_rg-raydemo-gzumb2_cluster-raydemo-gzumb2_westus3 --> Storage Account of fuse819db34db11346b58ab --> DataStorage --> Container of pvc-38112449-0e97-4b9e-94ff-e70300e2c7a9
   ```
   Note: The above script utilizes Azure Blob Storage by dynamically provisioning PersistentVolumes. The final model and checkpoint files can be accessed in the designated blob containers.
