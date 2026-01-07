# Loki + Observability Apps Setup Summary

## 🎉 What's Been Implemented

### 1. **Loki Stack (Log Aggregation)**
- **Location:** `apps/loki/`
- **Components:**
  - Loki server (log storage)
  - Promtail DaemonSet (collects logs from all pods)
  - Persistent storage: 5Gi (local-path)
  - Retention: 2 days
- **Access:** http://loki:3100 (internal)

### 2. **App A: Multi-Level Log Generator**
- **Location:** `apps/log-generator/`
- **Purpose:** Generates structured JSON logs with different severity levels
- **Features:**
  - Log levels: DEBUG, INFO, WARNING, ERROR, CRITICAL
  - Simulates 5 scenarios:
    - Successful transactions (50%)
    - Slow queries (20%)
    - Validation errors (15%)
    - Database errors (10%)
    - Critical errors (5%)
  - Structured JSON format with context (transaction_id, user_id, etc.)

### 3. **App B: REST API with Rich Logging**
- **Location:** `apps/rest-api/`
- **Technology:** Flask (Python)
- **Access:** http://api.local:30683
- **Endpoints:**
  - `GET /health` - Health check
  - `GET /api/users` - List users
  - `GET /api/users/<id>` - Get specific user
  - `POST /api/process` - Process data (60% success, 20% slow, 10% validation error, 10% server error)
  - `GET /api/slow` - Intentionally slow endpoint (2-5 seconds)
  - `GET /api/error` - Always returns 500 error
- **Logging:** Every request logged with duration, status code, request ID

### 4. **App C: Batch Job Simulator**
- **Location:** `apps/batch-job/`
- **Type:** Kubernetes CronJob
- **Schedule:** Every 5 minutes
- **Purpose:** Simulates batch processing
- **Features:**
  - Processes 50-200 records per run
  - 85% success rate
  - 10% recoverable errors (with retry)
  - 5% permanent failures
  - Logs progress, success rate, and issues

### 5. **Grafana Dashboards**
- **Updated:** Grafana now has Loki datasource configured
- **New Dashboard:** "Observability: Logs & Metrics"
  - 8 panels showing:
    1. Log volume by level (ERROR, WARNING, INFO)
    2. Error rate comparison (metrics vs logs)
    3. Recent ERROR logs
    4. Recent WARNING logs
    5. Logs by application
    6. REST API request duration (from logs)
    7. Batch job success rate
    8. Live log stream (all apps)

## 🚀 How to Deploy

All apps will be automatically deployed by Flux when you commit and push:

```bash
git add apps/
git commit -m "Add Loki log aggregation and observability apps

- Install Loki + Promtail for log aggregation (2-day retention)
- Add Log Generator app (multi-level structured logs)
- Add REST API with rich logging (Flask)
- Add Batch Job Simulator (CronJob every 5 min)
- Add Grafana dashboard for logs + metrics correlation
- Update ARCHITECTURE.md with new components

🤖 Generated with Claude Code"
git push
```

Flux will detect the changes and deploy everything within 1-2 minutes!

## 📊 How to Use & Test

### 1. **Wait for Deployment**
```bash
# Check Flux reconciliation
kubectl get helmreleases -A

# Watch pods starting
kubectl get pods -n loki
kubectl get pods -n log-generator
kubectl get pods -n rest-api
kubectl get pods -n batch-job
```

### 2. **Access Grafana**
- **Local:** http://grafana.local:30683
- **External:** https://engine-thinkpad-jonathan-tattoo.trycloudflare.com
- Navigate to: **Dashboards → Observability: Logs & Metrics**

### 3. **Test REST API** (Add to hosts file first!)
```powershell
# Add to C:\Windows\System32\drivers\etc\hosts
<cluster-ip> api.local
```

Then test:
```bash
# Health check
curl http://api.local:30683/health

# Get users
curl http://api.local:30683/api/users

# Trigger different scenarios
curl http://api.local:30683/api/users/5       # Success
curl http://api.local:30683/api/users/99      # 404 error
curl http://api.local:30683/api/slow          # Slow endpoint
curl http://api.local:30683/api/error         # 500 error
curl -X POST http://api.local:30683/api/process -H "Content-Type: application/json" -d '{"test": "data"}'
```

### 4. **View Logs in Grafana**

**Query Examples in Grafana Explore:**

```logql
# All logs from REST API
{namespace="rest-api"}

# Only ERROR logs
{namespace="rest-api"} | json | level="ERROR"

# Slow requests (>1000ms)
{namespace="rest-api"} | json | duration_ms > 1000

# All errors across all apps
{namespace=~"log-generator|rest-api|batch-job"} |~ "ERROR|CRITICAL"

# Batch job results
{namespace="batch-job"} | json | success_rate != ""

# Logs from last 5 minutes with request_id
{namespace="rest-api"} | json | request_id != ""
```

### 5. **Monitor Batch Jobs**
```bash
# Watch CronJob schedule
kubectl get cronjobs -n batch-job

# View completed jobs
kubectl get jobs -n batch-job

# Check logs of latest job
kubectl logs -n batch-job -l app=batch-processor --tail=50
```

## 🎯 What You Can Learn

1. **LogQL Queries** - Similar to PromQL but for logs
2. **Structured Logging** - JSON format makes filtering easy
3. **Log Correlation** - See logs + metrics together
4. **Distributed Logging** - Collect logs from multiple apps
5. **Log Retention** - Configure storage and cleanup policies
6. **Real-time Monitoring** - Live log streaming in Grafana

## 🔥 Cool Things to Try

1. **Trigger errors and watch logs appear in real-time**
   ```bash
   # Generate 10 requests (mix of success/errors)
   for i in {1..10}; do curl http://api.local:30683/api/process -X POST -H "Content-Type: application/json" -d '{}'; done
   ```

2. **Search for specific transaction**
   - Note a `request_id` from REST API logs
   - Search in Grafana: `{namespace="rest-api"} | json | request_id="abc12345"`
   - See the complete request lifecycle!

3. **Find slow operations**
   ```logql
   {namespace="rest-api"} | json | duration_ms > 500
   ```

4. **Monitor error rates**
   - Watch the dashboard panel "Error Rate (Logs + Metrics)"
   - Compare metrics (from Prometheus) vs logs (from Loki)

5. **Batch job analytics**
   - Wait for 2-3 batch runs (10-15 minutes)
   - Query: `{namespace="batch-job"} | json | batch_id != ""`
   - See processing patterns and success rates

## 📦 Repository Structure Update

```
apps/
├── loki/
│   ├── namespace.yaml
│   ├── helmrepository.yaml
│   ├── helmrelease.yaml
│   └── kustomization.yaml
│
├── log-generator/
│   ├── namespace.yaml
│   ├── deployment.yaml (with embedded Python code)
│   └── kustomization.yaml
│
├── rest-api/
│   ├── namespace.yaml
│   ├── deployment.yaml (Flask app)
│   ├── service.yaml
│   ├── ingress.yaml
│   └── kustomization.yaml
│
├── batch-job/
│   ├── namespace.yaml
│   ├── cronjob.yaml (batch processor)
│   └── kustomization.yaml
│
└── grafana/
    ├── helmrelease.yaml (updated with Loki datasource)
    ├── dashboard-configmap.yaml (existing metrics dashboard)
    └── logs-dashboard-configmap.yaml (NEW - logs + metrics)
```

## 🎓 Next Steps

1. **Commit and push** the changes
2. **Wait 1-2 minutes** for Flux to deploy
3. **Add api.local to hosts file**
4. **Open Grafana** and explore the new dashboard
5. **Generate traffic** to the REST API
6. **Watch logs appear** in real-time!

## 🆘 Troubleshooting

### Loki not starting?
```bash
kubectl describe pod -n loki -l app.kubernetes.io/name=loki
kubectl logs -n loki -l app.kubernetes.io/name=loki
```

### Promtail not collecting logs?
```bash
kubectl get pods -n loki -l app.kubernetes.io/name=promtail
kubectl logs -n loki -l app.kubernetes.io/name=promtail --tail=20
```

### REST API not accessible?
```bash
# Check pod status
kubectl get pods -n rest-api

# Check service
kubectl get svc -n rest-api

# Check ingress
kubectl get ingress -n rest-api

# View logs
kubectl logs -n rest-api -l app=rest-api
```

### No logs appearing in Grafana?
1. Check Promtail is running: `kubectl get pods -n loki`
2. Verify Loki datasource in Grafana (Configuration → Data Sources)
3. Try query: `{namespace="kube-system"}` (should always have logs)

---

**Created:** 2026-01-06
**Author:** Claude Code
**Purpose:** Complete observability stack with logs + metrics
