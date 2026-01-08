# Flux GitOps Status Dashboard

## 📊 Overview

The Flux GitOps Status dashboard provides real-time monitoring of your GitOps deployment pipeline. It shows the health and performance of all Flux CD resources managing your cluster.

**Access:** http://grafana.local:30683 → Dashboards → Flux GitOps Status

## 📈 Dashboard Panels

### Top Row - Status Overview

#### 1. Kustomization Status
- **Shows:** Number of ready Kustomizations
- **Color:**
  - 🟢 Green = All kustomizations ready
  - 🔴 Red = No kustomizations ready
- **What it means:** Kustomizations apply your manifests from Git to the cluster

#### 2. HelmRelease Status
- **Shows:** Number of ready HelmReleases
- **Color:**
  - 🟢 Green = All Helm releases deployed successfully
  - 🔴 Red = Helm releases failed
- **What it means:** Tracks Helm chart deployments (Grafana, Prometheus, Loki, etc.)

#### 3. GitRepository Sync Status
- **Shows:** Number of synced Git repositories
- **Color:**
  - 🟢 Green = Repository in sync
  - 🔴 Red = Repository sync failed
- **What it means:** Your GitHub repository is being monitored and fetched

#### 4. Failed Reconciliations
- **Shows:** Count of failed resources
- **Color:**
  - 🟢 Green = No failures
  - 🔴 Red = One or more resources failing
- **What it means:** Alert when any Flux resource is not reconciling properly

### Middle Row - Performance Metrics

#### 5. Reconciliation Duration (seconds)
- **Type:** Time series graph
- **Shows:** How long it takes to reconcile each resource type
- **Use:** Identify slow deployments or performance issues
- **Legend:** GitRepository, Kustomization, HelmRelease

#### 6. Reconciliation Rate (per minute)
- **Type:** Time series graph
- **Shows:** How often Flux is reconciling resources
- **Use:** Monitor GitOps activity and automation frequency
- **Normal:** Steady rate with spikes during Git commits

### Main Content - Detailed Status

#### 7. Resources by Status
- **Type:** Table
- **Columns:**
  - Resource Type (GitRepository, Kustomization, HelmRelease)
  - Name (e.g., "flux-system", "grafana", "prometheus")
  - Namespace
  - Condition (Ready, Stalled, etc.)
  - Status (True/False)
  - Ready (1 = ready, 0 = not ready)
- **Use:** Quick overview of all GitOps resources and their state

### Bottom Row - Health Checks

#### 8. Controller Status
- **Shows:** Individual Flux controller pod status
- **Color:**
  - 🟢 "UP" = Controller running
  - 🔴 "DOWN" = Controller failed
- **Controllers:**
  - source-controller
  - kustomize-controller
  - helm-controller
  - notification-controller

#### 9. Suspended Resources
- **Shows:** Count of manually suspended resources
- **Color:**
  - 🟢 Green = No suspended resources
  - 🟡 Yellow = Some resources suspended
- **What it means:** Resources you've paused for maintenance

#### 10. Last Successful Sync
- **Shows:** Time since last successful reconciliation
- **Color:**
  - 🟢 Green = Recently synced (< 5 min)
  - 🟡 Yellow = 5-10 minutes ago
  - 🔴 Red = > 10 minutes (may indicate problem)
- **Use:** Ensure your cluster is staying up-to-date with Git

## 🔧 Troubleshooting with the Dashboard

### Scenario 1: Git Commit Not Deploying
1. Check **GitRepository Sync Status** - Is it synced?
2. Check **Kustomization Status** - Is it ready?
3. Look at **Resources by Status** table - Find your resource
4. Check **Last Successful Sync** - When did it last update?

### Scenario 2: High Reconciliation Duration
1. View **Reconciliation Duration** graph
2. Identify which resource type is slow (GitRepository, Kustomization, HelmRelease)
3. Check **Resources by Status** to find specific slow resources
4. Review the resource configuration or cluster performance

### Scenario 3: Failed Resources
1. **Failed Reconciliations** panel shows red
2. Check **Resources by Status** table for Status = "False"
3. Use kubectl to get detailed error:
   ```bash
   kubectl describe kustomization <name> -n flux-system
   kubectl describe helmrelease <name> -n <namespace>
   ```

### Scenario 4: Controller Down
1. **Controller Status** shows "DOWN"
2. Check pod logs:
   ```bash
   kubectl logs -n flux-system deployment/source-controller
   kubectl logs -n flux-system deployment/kustomize-controller
   kubectl logs -n flux-system deployment/helm-controller
   ```
3. Restart controller if needed:
   ```bash
   kubectl rollout restart deployment/<controller> -n flux-system
   ```

## 📚 Understanding Flux Metrics

The dashboard uses these Prometheus metrics from Flux controllers:

- `gotk_reconcile_condition` - Resource status (Ready/NotReady)
- `gotk_reconcile_duration_seconds` - How long reconciliation takes
- `gotk_suspend_status` - Which resources are suspended
- `up{namespace="flux-system"}` - Controller health

## 🎯 Best Practices

1. **Monitor regularly** - Check the dashboard after Git commits
2. **Set up alerts** - Use the Failed Reconciliations metric for alerting
3. **Watch reconciliation duration** - Increasing times may indicate issues
4. **Keep controllers healthy** - All should show "UP"
5. **Investigate suspensions** - Understand why resources are suspended

## 🔗 Related Documentation

- [Flux CD Official Docs](https://fluxcd.io/flux/monitoring/)
- [Sealed Secrets](SEALED-SECRETS.md) - How we secure credentials
- [Architecture](../ARCHITECTURE.md) - Overall cluster design

---

**Dashboard Auto-refresh:** 30 seconds
**Time Range:** Configurable (default: Last 1 hour)
