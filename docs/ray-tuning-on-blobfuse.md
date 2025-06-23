# Run a Kuberay tuning job on AKS with Azure Blob Storage and Blobfuse

In this article, you will tune the GPT-2 large model using KubeRay, which will save the final model and checkpoints to an Azure Blob Storage account.

## Prerequisites
- Install Azure CLI by following [azure-cli](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?view=azure-cli-latest&pivots=apt) doc.
- Install terraform command line tool by following [installation](https://developer.hashicorp.com/terraform/install) doc.


### Quickstart
1. Clone the repository https://github.com/Azure-Samples/aks-ray-sample on to your local machine.
2. Navigate to the directory you cloned the repository and then navigate to sample-tunning-setup/terraform 
3. Enable execute permissions on the `deploy.sh` script by running `chmod +x deploy.sh`.
4. Run the `deploy.sh` script by running `./deploy.sh`. This script will deploy the AKS cluster, install the KubeRay operator then submit a training job pointing to azure blob storage to run on the AKS cluster

   Once the script finish execution, then open the URL displayed in the final line (see the example below for the script's last few lines).
   ```sh
   Current Kubernetes Context: cluster-raydemo-z5kmlg
   NAME                                 STATUS   ROLES    AGE     VERSION
   aks-nodepool1-17652229-vmss000000    Ready    <none>   2m10s   v1.32.4
   aks-nodepool1-17652229-vmss000001    Ready    <none>   2m43s   v1.32.4
   aks-nodepool1-17652229-vmss000002    Ready    <none>   2m14s   v1.32.4
   aks-nodepool1-17652229-vmss000003    Ready    <none>   2m40s   v1.32.4
   aks-nodepool1-17652229-vmss000004    Ready    <none>   2m39s   v1.32.4
   aks-nodepool1-17652229-vmss000005    Ready    <none>   2m42s   v1.32.4
   aks-systempool-69094345-vmss000000   Ready    <none>   9m37s   v1.32.4
   NAME                                                         READY   STATUS              RESTARTS   AGE
   ingress-nginx-controller-68547f7c99-cvk7n                    1/1     Running             0          61s
   kuberay-operator-b568bb49f-8splk                             1/1     Running             0          81s
   rayjob-tune-gpt2-raycluster-7qp9g-head-bvzpl                 0/1     ContainerCreating   0          34s
   rayjob-tune-gpt2-raycluster-7qp9g-large-group-worker-d7pvs   0/1     Init:0/2            0          34s
   rayjob-tune-gpt2-raycluster-7qp9g-large-group-worker-jgzn9   0/1     Init:0/2            0          34s
   rayjob-tune-gpt2-raycluster-7qp9g-large-group-worker-nr2dq   0/1     Init:0/2            0          34s
   rayjob-tune-gpt2-raycluster-7qp9g-large-group-worker-r9z5m   0/1     Init:0/2            0          34s
   rayjob-tune-gpt2-raycluster-7qp9g-large-group-worker-wbb8j   0/1     Init:0/2            0          34s
   Status: Running
   Job Status: Complete
   service/ray-dash exposed
   ingress.networking.k8s.io/ray-dash created
   KubeRay Dashboard URL: http://4.236.1.93/
   ```