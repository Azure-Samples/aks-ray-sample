#!/bin/bash

set -e

# Display help message
show_help() {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  --prefix_name    <PROJECT_PREFIX> Specify prefix of your project (defaults to azure)"
    echo "  --node_vm_size   <RAY_NODE_VM_SIZE> Specifies ray node vm size (defaults to Standard_D16s_v3)"
    echo "  --sa             <STORAGE_ACCOUNT_NAME> Specifies Storage Account Name"
    echo "  --sa_rg          <SA_RG_NAME> Storage Account Resource Group Name"
    echo "  --location       <LOCATION> Specifies Location name (defaults to eastus)"
    echo "  --adapter        <ADAPTER> Adapter to interact with Azure Blob [Choices: pyarrow] (defaults to pyarrow)"
    echo "  --cpus_perworker <CPUS_PER_WORKER> No.Of CPUs per worker [defaults: 8]"
    echo "  --num_workers    <NUM_WORKERS> No.Of Workers [defaults: No.Of Kubernetes Nodes]"
    echo "  --help           Show this help message"
    echo
    echo "Example:"
    echo "  $0 --name azure --prefix_name azure"
}

# Default values
PROJECT_PREFIX="azure"
RAY_NODE_VM_SIZE="Standard_D16s_v3"
STORAGE_ACCOUNT_NAME=""
LOCATION="eastus"
KUBERAY_NAMESPACE="kuberay"
num_workers=5
adapter="pyarrow"

subscription="$(az account show --query id --output tsv)"
epoch_date=$(date +%s)
mkdir -p ./${epoch_date}
TMP_DIR="./${epoch_date}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --help)
            show_help
            exit 0
            ;;
        --prefix_name)
            PROJECT_PREFIX="$2"
            shift 2
            ;;
        --node_vm_size)
            RAY_NODE_VM_SIZE="$2"
            shift 2
            ;;
	    --sa)
            STORAGE_ACCOUNT_NAME="$2"
	        shift 2
	        ;;
        --sa_rg)
            SA_RG_NAME="$2"
            shift 2
            ;;
	    --location)
	        LOCATION="$2"
	        shift 2
	        ;;
	    --adapter)
	        adapter="$2"
	        shift 2
	        ;;
        --num_workers)
	        num_workers="$2"
	        shift 2
	        ;;
	    --cpus_per_worker)
	        cpus_per_worker="$2"
            shift 2
            ;;	    
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

if [ -z "${STORAGE_ACCOUNT_NAME}" ]; then
echo "Please provide Storage Account Name through (--sa option) where Blob data present"
exit 1
fi

if [ -z "${SA_RG_NAME}" ]; then
echo "Please provide Storage Account ResourceGroup Name through (--sa_rg option) where Blob data present"
exit 1
fi

if [ "${adapter}" != "pyarrow" ]; then
	echo "Only parrow interface is supported as of now"
	exit 1
fi

RAY_NODE_COUNT=${num_workers}
declare -A config_map

echo "Configuration:"
echo "  PROJECT_PREFIX: ${PROJECT_PREFIX}"
echo "  RAY_NODE_COUNT: ${RAY_NODE_COUNT}"
echo "  RAY_NODE_VM_SIZE: ${RAY_NODE_VM_SIZE}"
echo "  STORAGE_ACCOUNT_NAME: ${STORAGE_ACCOUNT_NAME}"
echo "  SA_RG_NAME: ${SA_RG_NAME}"
echo "  LOCATION: ${LOCATION}"
echo "  KUBERAY_NAMESPACE: ${KUBERAY_NAMESPACE}"
echo "  adapter: ${adapter}"
echo "  num_workers: ${num_workers}"
echo "  cpus_per_worker: ${cpus_per_worker}"

## Configuration
config_map["project_prefix"]="${PROJECT_PREFIX}"
config_map["ray_workers"]="${num_workers}"
config_map["aks_node_pool_count"]="${RAY_NODE_COUNT}"
config_map["aks_node_pool_size"]="${RAY_NODE_VM_SIZE}"
config_map["storage_account_name"]="${STORAGE_ACCOUNT_NAME}"
config_map["storage_account_rg"]="${SA_RG_NAME}"
config_map["location"]="${LOCATION}"
config_map["app_namespace"]="${KUBERAY_NAMESPACE}"
config_map["adapter"]="${adapter}"
config_map["cpus_per_worker"]="${cpus_per_worker}"
config_map["tmp_dir"]="${TMP_DIR}"

RANDOM_STRING=$(cat /dev/urandom | tr -dc 'a-zA-Z' | fold -w 5 | head -n 1 | tr '[:upper:]' '[:lower:]')
RESOURCE_GROUP_NAME=$(echo "${PROJECT_PREFIX}-${RANDOM_STRING}-rg")
CLUSTER_NAME=$(echo "${PROJECT_PREFIX}-${RANDOM_STRING}-mc")

config_map["aks_resource_group"]="${RESOURCE_GROUP_NAME}"
config_map["aks_cluster_name"]="${CLUSTER_NAME}"

# Check if the user is logged into Azure CLI
if ! az account show > /dev/null 2>&1; then
    echo "Please login to Azure CLI using 'az login' before running this script."
    exit 1
fi

# Register if provider is not registered for given subscription
for provider in Microsoft.Monitor Microsoft.Dashboard; do
	registered_state=$(az provider show --namespace ${provider} --query registrationState -o tsv)
	if [ ${registered_state} != "Registered" ]; then
		az provider register --namespace ${provider}
	fi
done

echo "Creating Resource Group ${RESOURCE_GROUP_NAME}"
az group create --name "${RESOURCE_GROUP_NAME}" --location "${LOCATION}"
if [ $? -ne 0 ]; then
	echo "Failed to create resource group ${RESOURCE_GROUP_NAME}"
	exit 1
fi

echo "Creating Kubernetes Cluster having Resource Group Name: ${RESOURCE_GROUP_NAME} Cluster Name: ${CLUSTER_NAME}"
az aks create \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --name "${CLUSTER_NAME}" \
    --node-count "${num_workers}" \
    --node-vm-size "${RAY_NODE_VM_SIZE}" \
    --enable-oidc-issuer \
    --enable-workload-identity \
    --generate-ssh-keys


### # Initialize Terraform
### terraform init
### if [ $? -ne 0 ]; then
### 	echo "Failed to initialize terraform"
### 	exit 1
### fi
### 
### # Create a Terraform plan
### terraform plan -out main.tfplan
### if [ $? -ne 0 ]; then
### 	echo "Failed to execute terraform plan"
### 	exit 1
### fi
### 
### # Apply the Terraform plan
### terraform apply main.tfplan
### if [ $? -ne 0 ]; then
### 	echo "Failed to apply terrafrom"
### 	exit 1
### fi
### 
### # Retrieve the Terraform outputs and store in variables
### resource_group_name=$(terraform output -raw resource_group_name)
### system_node_pool_name=$(terraform output -raw system_node_pool_name)
### aks_cluster_name=$(terraform output -raw kubernetes_cluster_name)
### kuberay_namespace=$(terraform output -raw kubernetes_rayjob_namespace)
### grafana_name=$(terraform output -raw azure_grafana_dashboard_name)

# Get AKS credentials for the cluster
az aks get-credentials \
    --resource-group ${RESOURCE_GROUP_NAME} \
    --name ${CLUSTER_NAME}
if [ $? -ne 0 ]; then
	echo "Failed to get credentials of ${CLUSTER_NAME} cluster under ${RESOURCE_GROUP}"
	exit 1
fi

# Output the current Kubernetes context
current_context=$(kubectl config current-context)
echo "Current Kubernetes Context: $current_context"
# Output the nodes in the cluster
kubectl get nodes

# Get OIDC Issuer URL
aks_oidc_issuer="$(az aks show --name "${CLUSTER_NAME}" --resource-group "${RESOURCE_GROUP_NAME}" --query "oidcIssuerProfile.issuerUrl" --output tsv)"

# Create User Managed Identity
echo "Creating User Assigned Managed Identity"
uami="$(echo ${PROJECT_PREFIX}-${RANDOM_STRING}-mi)"
az identity create \
    --name "${uami}" \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --location "${LOCATION}" \
    --subscription "${subscription}"
config_map["user_assigned_managed_identity"]="${uami}"

echo "Fetching User Assigned Managed Identity Principal ID"
user_assigned_mi_principal_id="$(az identity show \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --name "${uami}" \
    --query 'principalId' \
    --output tsv)"

echo "Fetching User Assigned Managed Identity Client ID"
user_assigned_mi_client_id="$(az identity show \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --name "${uami}" \
    --query 'clientId' \
    --output tsv)"

## Grant Storage Blob Data Contributor role to above user assigned managed identity
echo "Assigning 'Storage Blob Data Contributor' role to User Assigned Managed Identity on Storage Account: ${STORAGE_ACCOUNT_NAME}"
set +e
set -x
role_assignment_cmd=$(echo "az role assignment create --role 'Storage Blob Data Contributor'  --assignee ${user_assigned_mi_principal_id} --scope /subscriptions/${subscription}/resourceGroups/${SA_RG_NAME}/providers/Microsoft.Storage/storageAccounts/${STORAGE_ACCOUNT_NAME}")
eval ${role_assignment_cmd}
role_assgnmt_rc=$?
set +x
set -e
if [ "${role_assgnmt_rc}" -ne 0 ]; then
	echo "❌ Permission issue detected. Please grant the required role manually."
	echo "Once done, type 'ok' and press Enter to continue..."
	read user_input
	if [[ "$user_input" != "ok" ]]; then
		echo "Exiting script as user did not confirm."
		exit 1
	fi
fi

echo "Deploying KubeRay Operator in ${KUBERAY_NAMESPACE} namespace"
helm repo add kuberay https://ray-project.github.io/kuberay-helm/
helm install kuberay-operator kuberay/kuberay-operator --version 1.6.0 --namespace ${KUBERAY_NAMESPACE} --create-namespace

# Output the pods in the kuberay namespace
kubectl get pods -n ${KUBERAY_NAMESPACE}

if [ -z "${num_workers}" ]; then
    num_workers=$(kubectl  get nodes --no-headers | wc -l)
    num_workers=$((num_workers - 1))
    echo "Defaulting Number of worker to no.of nodes - 1 i.e ${num_workers}"
fi


# Create Service Account
echo "Creating Service Account: ${PROJECT_PREFIX}-workload-identity in ${KUBERAY_NAMESPACE} namespace"
service_account_name=$(echo "${PROJECT_PREFIX}-workload-identity")
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    azure.workload.identity/client-id: "${user_assigned_mi_client_id}"
  name: "${service_account_name}"
  namespace: "${KUBERAY_NAMESPACE}"
EOF
config_map["service_account"]="${service_account_name}"

# Create Federated Identity Credential
federated_identity_credential_name=$(echo "${PROJECT_PREFIX}-${RANDOM_STRING}-fic")
echo "Creating Federated Identity Credential: ${federated_identity_credential_name}"
az identity federated-credential create \
    --name ${federated_identity_credential_name} \
    --identity-name "${uami}" \
    --resource-group "${RESOURCE_GROUP_NAME}" \
    --issuer "${aks_oidc_issuer}" \
    --subject system:serviceaccount:"${KUBERAY_NAMESPACE}":"${service_account_name}" \
    --audience api://AzureADTokenExchange
config_map["federated_credential_name"]="${federated_identity_credential_name}"

# Form Entrypoint command
if [ "${adapter}" == "pyarrow" ]; then
	echo "Using pyarrow interface to run inference model"
	entrypoint=$(echo "python sample-tuning-setup/direct-blob-access/train_batch_inference_pyarrow.py xgboost --size 10G --account-name ${STORAGE_ACCOUNT_NAME}")
elif [ "${adapter}" == "adlfs" ]; then
	echo "Using adlfs interface to run inference model"
	entrypoint=$(echo "python sample-tuning-setup/direct-blob-access/train_batch_inference_adlfs.py xgboost --size 10G --account-name ${STORAGE_ACCOUNT_NAME}")
fi

# Update --num-workers option
if [ ! -z ${num_workers} ]; then
	entrypoint=$(echo "${entrypoint} --num-workers ${num_workers}")
fi
# Update --cpus-per-worker option
if [ ! -z ${cpus_per_worker} ]; then
	entrypoint=$(echo "${entrypoint} --cpus-per-worker ${cpus_per_worker}")
fi

config_map["python_command"]="${entrypoint}"

cp ./rayjob_direct_access.tpl ${TMP_DIR}/rayjob_direct_access.yaml
sed -i s,@ENTRYPOINT@,"${entrypoint}",g ${TMP_DIR}/rayjob_direct_access.yaml
sed -i s,@SERVICE_ACCOUNT_NAME@,"${service_account_name}",g ${TMP_DIR}/rayjob_direct_access.yaml
sed -i s,@NUM_WORKERS@,"${num_workers}",g ${TMP_DIR}/rayjob_direct_access.yaml

echo "Submitting Ray Job"
kubectl apply -f ${TMP_DIR}/rayjob_direct_access.yaml -n ${KUBERAY_NAMESPACE}

json="{"
for key in "${!config_map[@]}"; do
  json+="\"$key\":\"${config_map[$key]}\","
done
# Remove trailing comma and close JSON object
json="${json%,}}"

echo "Metadata information of script stored under ${TMP_DIR}/.output.json"
echo "${json}" > "${TMP_DIR}/.output.json"
