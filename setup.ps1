$group      = "rg-aks-rollback"
$clusterName = "aksrollback"
$nodePool   = "nodepool1"
$location   = "eastus2"
$k8sVersion = "1.29.2"
$newVersion  = "1.30.0"

# create resource group
az group create -n $group -l $location

# create aks cluster
az aks create -n $clusterName -g $group -l $location `
  --kubernetes-version $k8sVersion `
  --node-count 2 `
  --generate-ssh-keys

# get credentials
az aks get-credentials -n $clusterName -g $group

# check available upgrades for the node pool
az aks nodepool get-upgrades -g $group --cluster-name $clusterName --nodepool-name $nodePool
 
# upgrade the node pool to a newer kubernetes version
az aks nodepool upgrade -g $group --cluster-name $clusterName `
  -n $nodePool `
  --kubernetes-version $newVersion
 
# confirm the node pool version after upgrade
az aks nodepool show -g $group --cluster-name $clusterName -n $nodePool `
  --query "orchestratorVersion" -o tsv