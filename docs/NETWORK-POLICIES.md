# Network Policies Documentation

## Overview

Network Policies provide pod-level firewall rules in Kubernetes, restricting traffic between namespaces and pods. This implements the principle of least privilege for network communication.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    NETWORK POLICY ARCHITECTURE                          │
└─────────────────────────────────────────────────────────────────────────┘

  Default State (Without Policies):
  ┌─────────────────────────────────────────────────────────────────────┐
  │  All pods can communicate with all other pods (no restrictions)     │
  └─────────────────────────────────────────────────────────────────────┘

  With Network Policies:
  ┌─────────────────────────────────────────────────────────────────────┐
  │  Default: DENY ALL ingress traffic                                  │
  │  Explicit: ALLOW only specific traffic flows                        │
  └─────────────────────────────────────────────────────────────────────┘

  Traffic Flow Diagram:

  ┌──────────────────┐     ┌──────────────────┐     ┌──────────────────┐
  │   kube-system    │     │    prometheus    │     │  order-pipeline  │
  │   (Traefik)      │     │                  │     │                  │
  └────────┬─────────┘     └────────┬─────────┘     └────────┬─────────┘
           │                        │                        │
           │ Ingress               │ Metrics               │ AMQP
           │ Traffic               │ Scraping              │ Messages
           ▼                        ▼                        ▼
  ┌──────────────────────────────────────────────────────────────────────┐
  │                         SMARTBIZ NAMESPACE                           │
  │  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐              │
  │  │ smartbiz-ui │◄───│ cloudflared │    │ postgres    │              │
  │  │   (nginx)   │    │  (tunnel)   │    │  (DB)       │              │
  │  └──────┬──────┘    └─────────────┘    └──────▲──────┘              │
  │         │                                      │                     │
  │         │ Proxy /api/*                        │ TCP/5432             │
  │         ▼                                      │                     │
  │  ┌─────────────┐                              │                     │
  │  │smartbiz-api │──────────────────────────────┘                     │
  │  │  (FastAPI)  │◄─── Prometheus scrapes metrics                     │
  │  └─────────────┘                                                    │
  └──────────────────────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────────────────┐
  │                         RABBITMQ NAMESPACE                           │
  │  ┌─────────────────────────────────────────────────────────────────┐│
  │  │                        rabbitmq                                  ││
  │  │  ◄─── AMQP (5672) from order-pipeline only                      ││
  │  │  ◄─── Metrics (15692) from prometheus only                      ││
  │  │  ◄─── Management UI (15672) from kube-system only               ││
  │  └─────────────────────────────────────────────────────────────────┘│
  └──────────────────────────────────────────────────────────────────────┘

  ┌──────────────────────────────────────────────────────────────────────┐
  │                      ORDER-PIPELINE NAMESPACE                        │
  │  ┌────────────┐ ┌────────────┐ ┌────────────┐ ┌────────────┐        │
  │  │  order-    │ │  payment-  │ │fulfillment-│ │notification│        │
  │  │ generator  │ │  service   │ │  service   │ │  service   │        │
  │  └────────────┘ └────────────┘ └────────────┘ └────────────┘        │
  │       ▲               ▲              ▲              ▲               │
  │       └───────────────┴──────────────┴──────────────┘               │
  │                    Prometheus scrapes all (8000-8003)               │
  └──────────────────────────────────────────────────────────────────────┘
```

## Implemented Policies

### SmartBiz Namespace (4 Policies)

| Policy | Target | Allowed Sources | Ports |
|--------|--------|-----------------|-------|
| `default-deny-ingress` | All pods | None (deny all) | - |
| `postgres-allow-api` | postgres | smartbiz-api | 5432 |
| `api-allow-ui-prometheus` | smartbiz-api | smartbiz-ui, prometheus namespace | 8000 |
| `ui-allow-ingress-tunnel` | smartbiz-ui | kube-system, cloudflared-smartbiz | 80 |

### RabbitMQ Namespace (2 Policies)

| Policy | Target | Allowed Sources | Ports |
|--------|--------|-----------------|-------|
| `default-deny-ingress` | All pods | None (deny all) | - |
| `rabbitmq-allow-pipeline-prometheus` | rabbitmq | order-pipeline ns, prometheus ns, kube-system | 5672, 15692, 15672 |

### Order-Pipeline Namespace (2 Policies)

| Policy | Target | Allowed Sources | Ports |
|--------|--------|-----------------|-------|
| `default-deny-ingress` | All pods | None (deny all) | - |
| `allow-prometheus-scrape` | All pods | prometheus namespace | 8000-8003 |

## File Structure

```
apps/network-policies/
├── kustomization.yaml           # Flux GitOps configuration
├── smartbiz-policies.yaml       # 4 policies for smartbiz namespace
├── rabbitmq-policies.yaml       # 2 policies for rabbitmq namespace
└── order-pipeline-policies.yaml # 2 policies for order-pipeline namespace
```

## How Network Policies Work

### Default Deny Pattern

Each namespace starts with a "default deny" policy:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: smartbiz
spec:
  podSelector: {}      # Applies to ALL pods in namespace
  policyTypes:
  - Ingress            # Blocks all incoming traffic
```

### Explicit Allow Pattern

Then specific traffic is allowed:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: postgres-allow-api
  namespace: smartbiz
spec:
  podSelector:
    matchLabels:
      app: postgres     # Applies to pods with app=postgres
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: smartbiz-api  # Only from pods with app=smartbiz-api
    ports:
    - protocol: TCP
      port: 5432
```

### Cross-Namespace Access

To allow traffic from another namespace:

```yaml
ingress:
- from:
  - namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: prometheus  # From prometheus namespace
  ports:
  - protocol: TCP
    port: 8000
```

## Security Benefits

### Before Network Policies
- Any pod could connect to PostgreSQL
- Any pod could send messages to RabbitMQ
- No isolation between namespaces
- Potential for lateral movement in case of compromise

### After Network Policies
- PostgreSQL only accessible from SmartBiz API
- RabbitMQ only accessible from Order-Pipeline microservices
- Prometheus can scrape metrics (explicit allow)
- Traefik can route ingress traffic (explicit allow)
- All other traffic blocked by default

## Verification Commands

### List All Network Policies

```bash
kubectl get networkpolicies -A
```

### Describe a Specific Policy

```bash
kubectl describe networkpolicy postgres-allow-api -n smartbiz
```

### Test Allowed Connection

```bash
# This should succeed (API can reach PostgreSQL)
kubectl exec -n smartbiz deployment/smartbiz-api -- nc -zv postgres 5432
```

### Test Blocked Connection

```bash
# This should fail (order-generator cannot reach PostgreSQL)
kubectl exec -n order-pipeline deployment/order-generator -- \
  nc -zv postgres.smartbiz.svc.cluster.local 5432
```

## Troubleshooting

### Application Can't Connect After Policy Applied

1. **Check pod labels:**
   ```bash
   kubectl get pods -n smartbiz --show-labels
   ```

2. **Verify policy selectors match:**
   ```bash
   kubectl describe networkpolicy postgres-allow-api -n smartbiz
   ```

3. **Check namespace labels:**
   ```bash
   kubectl get ns --show-labels
   ```

### Prometheus Can't Scrape Metrics

1. **Verify prometheus namespace label:**
   ```bash
   kubectl get ns prometheus --show-labels
   ```

2. **Check if `kubernetes.io/metadata.name: prometheus` exists**

3. **If missing, add it:**
   ```bash
   kubectl label namespace prometheus kubernetes.io/metadata.name=prometheus
   ```

### Quick Rollback

If policies break connectivity:

```bash
# Delete all network policies (immediate effect)
kubectl delete networkpolicies --all -n smartbiz
kubectl delete networkpolicies --all -n rabbitmq
kubectl delete networkpolicies --all -n order-pipeline
```

Or via GitOps:

```bash
# Remove the network-policies directory
git rm -r apps/network-policies/
git commit -m "Rollback network policies"
git push
```

## Adding Policies for New Applications

When adding a new application that needs network isolation:

### 1. Create Default Deny Policy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: your-namespace
spec:
  podSelector: {}
  policyTypes:
  - Ingress
```

### 2. Add Specific Allow Rules

Identify traffic flows:
- Which pods need to be accessed?
- From which sources? (same namespace, other namespace, external)
- On which ports?

### 3. Create Allow Policies

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: your-app-allow-source
  namespace: your-namespace
spec:
  podSelector:
    matchLabels:
      app: your-app
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: allowed-source
    ports:
    - protocol: TCP
      port: 8080
```

### 4. Test Connectivity

Always test after applying:
- Application still works
- Prometheus can scrape metrics
- Ingress traffic reaches pods

## Related Documentation

- [ARCHITECTURE.md](../ARCHITECTURE.md) - Overall cluster architecture
- [SMARTBIZ.md](SMARTBIZ.md) - SmartBiz application documentation
- [RABBITMQ-PIPELINE.md](RABBITMQ-PIPELINE.md) - Order processing pipeline

---

**Implemented:** 2026-01-17
**Status:** Active
**Policies:** 8 NetworkPolicy resources across 3 namespaces
