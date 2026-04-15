$group = "rg-aks-rollback"
$clusterName = "aksrollback"
$nodePool = "nodepool1"
$location = "eastus2"
$k8sVersion = "1.33"
$newVersion = "1.34"

# create resource group
az group create -n $group -l $location

# create aks cluster
az aks create -n $clusterName -g $group -l $location `
    --kubernetes-version $k8sVersion `
    --node-count 2 `
    --nodepool-name $nodePool `
    --generate-ssh-keys

# wait for cluster provisioning to complete
az aks wait -n $clusterName -g $group --created

# check available control plane upgrades
az aks get-upgrades -n $clusterName -g $group

# upgrade the control plane first
az aks upgrade -n $clusterName -g $group `
    --kubernetes-version $newVersion `
    --control-plane-only `
    --yes

# confirm the control plane version after upgrade
az aks show -n $clusterName -g $group `
    --query "kubernetesVersion" -o tsv

# get credentials
az aks get-credentials -n $clusterName -g $group

# check available upgrades for the node pool
az aks nodepool get-upgrades -g $group --cluster-name $clusterName --nodepool-name $nodePool
 
# upgrade the node pool to a newer kubernetes version
az aks nodepool upgrade -g $group --cluster-name $clusterName `
    -n $nodePool `
    --kubernetes-version $newVersion `
    --yes
 
# confirm the node pool version after upgrade
az aks nodepool show `
    -g $group `
    --cluster-name $clusterName -n $nodePool `
    --query "orchestratorVersion" -o tsv