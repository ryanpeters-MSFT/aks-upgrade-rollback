# AKS Node Pool Rollback Demo

This repo demonstrates the AKS node pool rollback feature described in the Microsoft Learn article for [rolling back node pool versions in AKS](https://learn.microsoft.com/en-us/azure/aks/roll-back-node-pool-version).

[setup.ps1](./setup.ps1) creates an AKS cluster, upgrades the control plane, and upgrades the node pool so you have a rollback scenario to test.

## Run

```powershell
.\setup.ps1
```

## Check Available Upgrades

Get available cluster upgrade versions:

```powershell
az aks get-upgrades --resource-group rg-aks-rollback --name aksrollback
```

Get available upgrade versions for a specific node pool:

```powershell
az aks nodepool get-upgrades --resource-group rg-aks-rollback --cluster-name aksrollback --nodepool-name nodepool1
```

## Roll Back The Node Pool

The feature is currently documented as preview. Per Microsoft Learn, you need:

- Azure CLI 2.64.0 or later
- The `aks-preview` extension

```powershell
az extension add --name aks-preview
az extension update --name aks-preview
```

Rollback command:

```powershell
az aks nodepool rollback --name nodepool1 --resource-group rg-aks-rollback --cluster-name aksrollback
```

### Node OS Versions

If `nodeOSUpgradeChannel` is enabled, AKS can roll back the orchestrator version but not the node image. In this case, rollback returns an error:

```
nodeOSUpgradeChannel is enabled on cluster 'aksrollback' (nodeOSUpgradeChannel=NodeImage). The orchestrator version rollback will proceed, but the node image rollback will not succeed. Please disable nodeOSUpgradeChannel if you want to roll back the node image.
```

Disable the channel before running rollback if you want the node image to roll back as well:

```powershell
az aks update --resource-group rg-aks-rollback --name aksrollback --node-os-upgrade-channel None
```

## Notes/Observarions

- Rollback is available only within seven days of the upgrade.
- Rollbacks are performed in the same manner as a rolling upgrade
- Only nodepools are rolled back - the control plane is not
- It rolls back the node pool version and node image to the previous state.
- It is meant as a temporary recovery step, not a long-term state.