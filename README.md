# AKS Node Pool Rollback Demo

This repo sets up a small AKS environment that gives you a real node pool rollback scenario to test.

The PowerShell script in `setup.ps1` does the following:

1. Creates a resource group named `rg-aks-rollback` in `eastus2`.
2. Creates an AKS cluster named `aksrollback` with node pool `nodepool1` on Kubernetes `1.33`.
3. Waits for the cluster creation to finish.
4. Upgrades only the control plane to `1.34`.
5. Upgrades the node pool to `1.34`.

At that point, you have an upgraded node pool that can be rolled back with the current [AKS rollback workflow](https://learn.microsoft.com/en-us/azure/aks/roll-back-node-pool-version#node-pool-rollback-workflow).

## Run

```powershell
.\setup.ps1
```

## Check Upgrade And Rollback Options

Check control plane upgrade targets:

```powershell
az aks get-upgrades -g rg-aks-rollback -n aksrollback
```

Check node pool upgrade targets:

```powershell
az aks nodepool get-upgrades -g rg-aks-rollback --cluster-name aksrollback --nodepool-name nodepool1
```

Check rollback history that AKS can use for node pool rollback:

```powershell
az aks nodepool get-rollback-versions -g rg-aks-rollback --cluster-name aksrollback --nodepool-name nodepool1
```

## Roll Back The Node Pool

Run the rollback:

```powershell
az aks nodepool rollback -g rg-aks-rollback --cluster-name aksrollback --nodepool-name nodepool1
```

The current [CLI reference for `az aks nodepool rollback`](https://learn.microsoft.com/en-us/cli/azure/aks/nodepool?view=azure-cli-latest#az-aks-nodepool-rollback) describes this as rolling the node pool back to the most recently used configuration (`N-1`). That rollback restores both the Kubernetes version and the node image version to the most recent prior compatible state.

If you want to watch the operation after using `--no-wait` on other AKS commands, use:

```powershell
az aks nodepool wait -g rg-aks-rollback --cluster-name aksrollback --nodepool-name nodepool1 --updated
```

## Duration And Timeout Parameters

This repo itself does not pass custom timeout or soak settings, but the current AKS docs define several duration-related controls that matter when you test upgrades and rollbacks. See the [rolling node pool upgrade settings](https://learn.microsoft.com/en-us/azure/aks/upgrade-aks-node-pools-rolling#configure-rolling-upgrade-settings), [blue-green upgrade properties](https://learn.microsoft.com/en-us/azure/aks/blue-green-node-pool-upgrade#customize-blue-green-upgrade-properties), and [`az aks wait` CLI reference](https://learn.microsoft.com/en-us/cli/azure/aks?view=azure-cli-latest#az-aks-wait).

### Rollback Window

- Standard node pool rollback is available only for seven days after the upgrade completes.
- Blue-green rollback is different: rollback is only available during the configured `finalSoakDurationInMinutes` window of that blue-green upgrade.

### `az aks wait` Timeout Behavior

The script uses:

```powershell
az aks wait -n aksrollback -g rg-aks-rollback --created
```

No explicit wait values are passed, so the [documented `az aks wait` defaults](https://learn.microsoft.com/en-us/cli/azure/aks?view=azure-cli-latest#az-aks-wait) apply:

- `--interval`: `30` seconds.
- `--timeout`: `3600` seconds.

If cluster creation takes longer than one hour, you can raise the timeout explicitly:

```powershell
az aks wait -n aksrollback -g rg-aks-rollback --created --interval 60 --timeout 5400
```

### Rolling Upgrade Durations

These settings apply to rolling node pool upgrades and influence how upgrade-created rollback scenarios behave:

- `--drain-timeout`: how many minutes AKS waits for pods to be evicted from a node before the operation stops.
	- Default: `30` minutes.
	- Minimum: `5` minutes.
	- Maximum: `1440` minutes (24 hours).
- `--node-soak-duration`: how many minutes AKS waits after draining a node before reimaging it and moving to the next node.
	- Default: `0` minutes.
	- Minimum: `0` minutes.
	- Maximum: `30` minutes.
- `--max-surge`: extra nodes added during a rolling upgrade.
	- Default behavior is effectively one extra node if you do not customize it.
	- Accepted as an integer or percentage.
- `--max-unavailable`: number or percentage of nodes that can be unavailable during an in-place rolling upgrade.
	- Requires `--max-surge 0`.
	- Not supported on system node pools.
- `--undrainable-node-behavior`: controls how AKS handles nodes that cannot be drained during upgrade.
	- Accepted values: `Cordon` or `Schedule`.

Example rolling upgrade with explicit timing controls:

```powershell
az aks nodepool upgrade -g rg-aks-rollback --cluster-name aksrollback -n nodepool1 --kubernetes-version 1.34 --drain-timeout 45 --node-soak-duration 5 --max-surge 33% --yes
```

### Blue-Green Upgrade Durations

If you test blue-green node pool upgrades instead of the default rolling strategy, the [blue-green upgrade docs](https://learn.microsoft.com/en-us/azure/aks/blue-green-node-pool-upgrade#customize-blue-green-upgrade-properties) define separate timing parameters:

- `--drain-timeout-bg`: pod eviction timeout per node during the blue-green drain phase.
	- Default: `30` minutes.
	- Range: `1` to `1440` minutes.
- `--batch-soak-duration`: pause between drain batches.
	- Default: `15` minutes.
	- Range: `0` to `1440` minutes.
- `--final-soak-duration`: final validation window after all old nodes are drained and before old nodes are removed.
	- Default: `60` minutes.
	- Range: `0` to `10080` minutes (seven days).
	- Blue-green rollback is only available during this final soak period.
- `--drain-batch-size`: integer or percentage of blue nodes drained per batch.
	- Default: `10%`.
	- Must be non-zero.

Example blue-green upgrade:

```powershell
az aks nodepool upgrade -g rg-aks-rollback --cluster-name aksrollback -n nodepool1 --kubernetes-version 1.34 --upgrade-strategy BlueGreen --drain-batch-size 50% --drain-timeout-bg 5 --batch-soak-duration 10 --final-soak-duration 180 --yes
```

## Current Limitations And Accuracy Notes

These points are current per the latest [rollback limitations and considerations](https://learn.microsoft.com/en-us/azure/aks/roll-back-node-pool-version#node-pool-rollback-limitations-and-considerations), [rolling upgrade settings](https://learn.microsoft.com/en-us/azure/aks/upgrade-aks-node-pools-rolling#configure-rolling-upgrade-settings), and [blue-green upgrade limitations](https://learn.microsoft.com/en-us/azure/aks/blue-green-node-pool-upgrade#blue-green-upgrade-limitations-and-considerations) docs:

- Rollback is limited to version changes. It does not revert unrelated node pool configuration changes.
- The rollback operation is node pool scoped only. It does not roll back the AKS control plane.
- You cannot perform concurrent operations on that node pool during rollback.
- If cluster autoupgrade is configured, you must disable it before rollback.
- You cannot use rollback to step back multiple versions consecutively.
- You cannot roll back to a Kubernetes version that is no longer supported by AKS.
- OS SKU changes are not reverted by node pool rollback. If you changed the pool from something like Ubuntu to Azure Linux, use `az aks nodepool update --os-sku ...` instead of expecting rollback to reverse the OS migration.
- If you only updated the node image within the last seven days, rollback can restore the previous node image while keeping the same Kubernetes version.
- Rollback should be treated as a temporary recovery measure, not a steady-state operating model.

## Links

- Microsoft Learn: roll back node pool versions in AKS: https://learn.microsoft.com/en-us/azure/aks/roll-back-node-pool-version
- Azure CLI reference: `az aks nodepool`: https://learn.microsoft.com/en-us/cli/azure/aks/nodepool?view=azure-cli-latest
- Microsoft Learn: rolling node pool upgrades: https://learn.microsoft.com/en-us/azure/aks/upgrade-aks-node-pools-rolling
- Microsoft Learn: blue-green node pool upgrades: https://learn.microsoft.com/en-us/azure/aks/blue-green-node-pool-upgrade
- Microsoft Learn: upgrade the AKS control plane: https://learn.microsoft.com/en-us/azure/aks/upgrade-aks-control-plane
- Microsoft Learn: upgrade AKS node images: https://learn.microsoft.com/en-us/azure/aks/upgrade-node-image
- Microsoft Learn: supported AKS Kubernetes versions: https://learn.microsoft.com/en-us/azure/aks/supported-kubernetes-versions