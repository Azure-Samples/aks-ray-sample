
# Deploy a Ray cluster on Azure Kubernetes Service (AKS) overview

In this article, you learn how to deploy a Ray cluster on Azure Kubernetes Service (AKS) using the KubeRay operator. You also learn how to use the Ray cluster to train a simple machine learning model and display the results on the Ray dashboard.

> ![!NOTE]
> Open-source software is mentioned throughout AKS documentation and samples. Software that you deploy is excluded from AKS service-level agreements, limited warranty, and Azure support. As you use open-source technology alongside AKS, consult the support options available from the respective communities and project maintainers to develop a plan.
>
> For example, the [Ray GitHub repository](https://github.com/ray-project/ray?tab=readme-ov-file#getting-involved) describes several platforms that vary in response time, purpose, and support level.
>
> Microsoft takes responsibility for building the open-source packages that we deploy on AKS. That responsibility includes having complete ownership of the build, scan, sign, validate, and hotfix process, along with control over the binaries in container images. For more information, see [Vulnerability management for AKS](https://github.com/MicrosoftDocs/azure-aks-docs/blob/main/articles/aks/concepts-vulnerability-management.md#aks-container-images) and [AKS support coverage](https://github.com/MicrosoftDocs/azure-aks-docs/blob/main/articles/aks/support-policies.md#aks-support-coverage).

## What is Ray?

[Ray](https://docs.ray.io/en/latest/index.html#) is an open-source project developed at UC Berkeley's RISE Lab that provides a unified framework for scaling AI and Python applications. It consists of a core distributed runtime and a set of AI libraries designed to accelerate machine learning workloads.

Ray simplifies the process of running compute-intensive Python tasks at scale, allowing you to seamlessly scale your applications. The framework supports various machine learning tasks, including distributed training, hyperparameter tuning, reinforcement learning, and production model serving.

For more information, see the [Ray GitHub repository](https://github.com/ray-project/ray).

## What is KubeRay?

[KubeRay](https://docs.ray.io/en/latest/cluster/kubernetes/getting-started.html) is an open-source Kubernetes operator for deploying and managing Ray clusters on Kubernetes. KubeRay automates the deployment, scaling, and monitoring of Ray clusters. It provides a declarative way to define Ray clusters using Kubernetes custom resources, making it easy to manage Ray clusters alongside other Kubernetes resources.

For more information, see the [KubeRay GitHub repository](https://github.com/ray-project/kuberay).

## Ray deployment process

The deployment process consists of the following steps:

1. Use Terraform to create a local plan file to define the desired state for infrastructure required AKS infrastructure that consists of an Azure resource group, a dedicated system node pool, and a workload node pool for Ray with three nodes.
2. Deploy a local Terraform plan to Azure.
3. Retrieve outputs from the Terraform deployment and obtain Kubernetes credentials to the newly deployed AKS cluster.
4. Install the Helm Ray repository and deploy KubeRay to the AKS cluster using Helm.
5. Download and execute a [Ray Job](https://docs.ray.io/en/latest/cluster/running-applications/job-submission/index.html) YAML manifest from the Ray GitHub samples repo to perform an image classification with a [MNIST](https://github.com/cvdfoundation/mnist) dataset using [Convolutional Neural Networks (CNNs)](https://techcommunity.microsoft.com/discussions/machinelearning/what-is-convolutional-neural-network-%E2%80%94-cnn-deep-learning/4184725).
6. Output the logs from the Ray Job to gain insight into the machine learning process performed by Ray.

## Next step

> [!div class="nextstepaction"]
> [Configure and deploy a Ray cluster on Azure Kubernetes Service (AKS) using KubeRay](./deploy-ray-aks.md)

## Contributors

*Microsoft maintains this article. The following contributors originally wrote it:*

- Russell de Pina | Principal Technical Program Manager - Microsoft
- Ken Kilty | Principal Technical Program Manager - Microsoft
- Erin Schaffer | Content Developer 2 - Microsoft