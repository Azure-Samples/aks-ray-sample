# aks-ray-sample

This sample shows how to deploy a Ray cluster on an Azure Kubernetes Service (AKS) cluster using the KubeRay operator. The sample also shows how to run a simple Ray application on the cluster.

## Getting Started

Clone the repository to your local machine. Then make sure you have all the prerequisites installed.

### Prerequisites

1. An Azure subscription. If you don't have an Azure subscription, you can create a free account [here](https://azure.microsoft.com/free/).
1. The Azure CLI installed on your local machine. You can install the Azure CLI by following the instructions [here](https://docs.microsoft.com/cli/azure/install-azure-cli).
1. The [Azure Kubernetes Service Preview extension](https://learn.microsoft.com/azure/aks/draft#install-the-aks-preview-azure-cli-extension) must be installed.
1. [Helm](https://helm.sh/docs/intro/install/) must be installed.
1. [Terraform client tools](https://developer.hashicorp.com/terraform/install) or [OpenTofu](https://opentofu.org/) must be installed. This guide makes use of Terrafrom, however the modules used should be compatible with OpenTofu.

### Quickstart

1. Clone the repository [https://github.com/Azure-Samples/aks-ray-sample](https://github.com/Azure-Samples/aks-ray-sample) on to your local machine.
2. Navigate to the directory you cloned the repository to.
3. Enable execute permissions on the `deploy.sh` script by running `chmod +x deploy.sh`.
4. Run the `deploy.sh` script by running `./deploy.sh`. This script will deploy the AKS cluster, install the KubeRay operator then submit a training job to run on the AKS cluster.

## Modle tuning with Ray

YOu can run model tuning jobs easily on Ray cluster with Azure Blob storage. See the steps in [Ray tuning on Azure Blobs](./docs/ray-tuning-on-blobfuse.md)

## Resources

- [Ray on Kubernetes](https://docs.ray.io/en/latest/cluster/kubernetes/index.html)
- [KubeRay project](https://github.com/ray-project/kuberay)
