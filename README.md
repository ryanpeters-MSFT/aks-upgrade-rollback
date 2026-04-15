# AKS Node Pool Rollback Demo

This repo demonstrates the AKS node pool rollback feature described in the Microsoft Learn article for [rolling back node pool versions in AKS](https://learn.microsoft.com/en-us/azure/aks/roll-back-node-pool-version).

[setup.ps1](./setup.ps1) creates an AKS cluster, upgrades the control plane, and upgrades the node pool so you have a rollback scenario to test.

## Run

```powershell
.\setup.ps1
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

Important limits from the doc:

- Rollback is available only within seven days of the upgrade.
- It rolls back the node pool version and node image to the previous state.
- It is meant as a temporary recovery step, not a long-term state.