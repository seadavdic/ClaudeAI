# AlertManager & Complete Observability Stack Setup

## 🎉 What's Been Deployed

### 1. **AlertManager** (`apps/alertmanager/`)
- **Purpose**: Handles alerts from Prometheus and routes them to notification channels
- **Components**:
  - AlertManager StatefulSet (persistent alert state)
  - Persistent storage: 2Gi (local-path)
  - Webhook receivers for different alert types
- **Access**:
  - Local: http://alertmanager.local:30683
  - External: Configure Traefik Ingress

### 2. **Alert Webhook Receiver** (`apps/alert-webhook/`)
- **Purpose**: Receives alerts from AlertManager and logs them (visible in Loki)
- **Endpoints**:
  - `/webhook` - Default alerts
  - `/webhook/critical` - Critical alerts (logged as CRITICAL level)
  - `/webhook/batch-jobs` - Batch job specific alerts
  - `/webhook/infrastructure` - Infrastructure/node alerts
- **Features**:
  - Structured JSON logging
  - Severity-based log levels
  - All logs collected by Promtail → Loki
  - Viewable in Grafana Explore

### 3. **Prometheus Alert Rules**
Three groups of alert rules configured:

#### Application Metrics Alerts
- **HighErrorRate**: Fires when error rate > 10 errors/sec for 2 minutes
- **HighRequestRate**: Informational alert when request rate > 100 req/sec
- **SlowResponseTime**: Fires when p95 response time > 2 seconds

#### Infrastructure Alerts
- **HighCPUUsage**: Node CPU usage > 80% for 5 minutes
- **HighMemoryUsage**: Node memory usage > 85% for 5 minutes
- **HighTemperature**: Raspberry Pi temperature > 75°C for 5 minutes
- **NodeDown**: Node Exporter unreachable for 1 minute (CRITICAL)
- **DiskSpaceRunningLow**: Disk space < 15% remaining

### 4. **Node Exporter** (Already enabled in Prometheus)
- **Purpose**: Collects hardware and OS metrics from both Raspberry Pis
- **Metrics collected**:
  - CPU usage per core
  - Memory usage (total, available, used)
  - Disk usage and I/O
  - Network traffic (RX/TX)
  - System load (1m, 5m, 15m)
  - CPU temperature
  - Uptime
- **Deployment**: DaemonSet (runs on every node)

### 5. **Grafana Dashboard: "Raspberry Pi Cluster Monitoring"**
New dashboard with 9 panels:

1. **CPU Usage by Node** - Time series showing CPU% for each Pi (displays node names)
2. **Memory Usage by Node** - Time series with thresholds (yellow @ 75%, red @ 85%)
3. **CPU Temperature** - Gauge showing current temperature per node
4. **Disk Usage** - Gauge showing disk space used
5. **Network Traffic (Receive)** - Time series of incoming network traffic
6. **Network Traffic (Transmit)** - Time series of outgoing network traffic
7. **System Load** - Time series showing 1m, 5m, 15m load averages
8. **Uptime** - How long each node has been running
9. **Active Alerts** - Shows currently firing alerts (count)

**Note**: All panels display node names (k3s-master, k3s-worker-1) instead of IP addresses for better readability.

**Auto-refresh**: 30 seconds
**Time range**: Last 1 hour

---

## 🚀 How to Access

### AlertManager UI
```
Local: http://alertmanager.local:30683
```

Add to your hosts file:
```
<cluster-ip> alertmanager.local
```

**Features**:
- View active alerts
- Silence alerts temporarily
- See alert grouping and routing
- View alert history

### Grafana Dashboards
```
Local: http://grafana.local:30683
External: https://engine-thinkpad-jonathan-tattoo.trycloudflare.com
```

**Available Dashboards**:
1. Web Server Metrics (existing)
2. Complete Observability Dashboard (logs + metrics)
3. **Raspberry Pi Cluster Monitoring** (NEW!)

### Viewing Alerts in Loki
In Grafana → Explore → Select Loki datasource:

```logql
{namespace="alertmanager", service="alert-webhook"}
```

Filter by severity:
```logql
{namespace="alertmanager"} | json | level="WARNING"
{namespace="alertmanager"} | json | level="CRITICAL"
```

---

## 📊 Alert Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    ALERT PIPELINE                           │
└─────────────────────────────────────────────────────────────┘

Step 1: Metric Collection
┌────────────────────────┐
│  Metrics App (custom)  │───► http_errors_total
│  Node Exporter (nodes) │───► node_cpu_seconds_total
│  Kube State Metrics    │───► kube_pod_status_phase
└────────┬───────────────┘
         │ Scraped every 30s
         ▼
Step 2: Prometheus Evaluation
┌────────────────────────────────────────┐
│  Prometheus Server                     │
│                                        │
│  Evaluates alert rules every 30s:     │
│  ├─ HighErrorRate (2m threshold)      │
│  ├─ HighCPUUsage (5m threshold)       │
│  ├─ NodeDown (1m threshold)           │
│  └─ ... 8 total alert rules           │
└────────┬───────────────────────────────┘
         │ Alert FIRING
         ▼
Step 3: AlertManager Processing
┌──────────────────────────────────────────┐
│  AlertManager                            │
│                                          │
│  Groups alerts by:                       │
│  ├─ alertname (e.g., HighCPUUsage)      │
│  ├─ cluster                              │
│  └─ service                              │
│                                          │
│  Routes to receivers:                    │
│  ├─ severity=critical → critical webhook│
│  ├─ component=infrastructure → infra WH │
│  └─ default → default webhook           │
└────────┬─────────────────────────────────┘
         │ HTTP POST
         ▼
Step 4: Webhook Receiver
┌──────────────────────────────────────────┐
│  Alert Webhook (Python Flask)            │
│                                          │
│  Receives alert JSON payload             │
│  Logs to stdout with severity:           │
│  ├─ firing → WARNING/CRITICAL            │
│  └─ resolved → INFO                      │
└────────┬─────────────────────────────────┘
         │ stdout logs
         ▼
Step 5: Log Collection
┌──────────────────────────────────────────┐
│  Promtail DaemonSet                      │
│  Scrapes all pod logs                    │
│  Sends to Loki                           │
└────────┬─────────────────────────────────┘
         │
         ▼
Step 6: Visualization
┌──────────────────────────────────────────┐
│  Grafana                                 │
│  ├─ View alerts in Loki Explore          │
│  ├─ "Active Alerts" panel shows firing   │
│  └─ Create alert-based dashboards        │
└──────────────────────────────────────────┘
```

---

## 🧪 Testing Alerts

### Test 1: Simulate High Error Rate
Manually trigger errors in the metrics app (this would require modifying the metrics app to generate more errors temporarily).

### Test 2: Check Node Status Alert
```bash
# Stop Node Exporter on one node to trigger NodeDown alert
kubectl scale deployment prometheus-prometheus-node-exporter --replicas=0 -n prometheus

# Wait 1 minute, then check AlertManager UI
# You should see "NodeDown" alert firing

# Restore Node Exporter
kubectl scale deployment prometheus-prometheus-node-exporter --replicas=2 -n prometheus
```

### Test 3: View Alerts in Loki
After alerts start firing:

1. Open Grafana → Explore
2. Select Loki datasource
3. Query: `{namespace="alertmanager"} | json | level="WARNING"`
4. You'll see alert webhook logs showing which alerts fired

---

## 📋 Alert Configuration

### Adding Email Notifications
Edit `apps/alertmanager/helmrelease.yaml`:

```yaml
receivers:
  - name: 'default'
    email_configs:
      - to: 'your-email@example.com'
        from: 'alertmanager@your-cluster.local'
        smarthost: 'smtp.gmail.com:587'
        auth_username: 'your-email@example.com'
        auth_password: 'your-app-password'  # Use App Password for Gmail
        headers:
          Subject: '[ALERT] {{ .GroupLabels.alertname }}'
```

Commit and push - Flux will update AlertManager automatically.

### Adding Slack Notifications
```yaml
receivers:
  - name: 'critical'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
        channel: '#alerts'
        title: '🚨 Critical Alert'
        text: '{{ .CommonAnnotations.summary }}'
```

### Adding Discord Notifications
Use webhook_configs with Discord webhook URL:

```yaml
receivers:
  - name: 'critical'
    webhook_configs:
      - url: 'https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_WEBHOOK_TOKEN/slack'
        send_resolved: true
```

---

## 🎯 What You Can Monitor Now

### Application Performance
✅ Error rates and types
✅ Request rates and distribution
✅ Response time percentiles (p50, p95, p99)
✅ Active connections

### Infrastructure Health
✅ CPU usage per node
✅ Memory usage per node
✅ Disk space usage
✅ Network traffic (RX/TX)
✅ System load averages
✅ Node temperature (important for Raspberry Pi!)
✅ Node uptime
✅ Node availability (up/down)

### Logging & Observability
✅ Structured logs from all apps
✅ Log aggregation with Loki
✅ Log levels: DEBUG, INFO, WARNING, ERROR, CRITICAL
✅ Batch job success/failure tracking
✅ REST API request/response logging
✅ Alert notifications logged to Loki

---

## 📈 Metrics Available

### From Node Exporter:
- `node_cpu_seconds_total` - CPU time per mode (idle, user, system)
- `node_memory_MemTotal_bytes` / `node_memory_MemAvailable_bytes` - Memory stats
- `node_filesystem_avail_bytes` / `node_filesystem_size_bytes` - Disk stats
- `node_network_receive_bytes_total` / `node_network_transmit_bytes_total` - Network stats
- `node_load1` / `node_load5` / `node_load15` - System load
- `node_hwmon_temp_celsius` - CPU temperature
- `node_boot_time_seconds` / `node_time_seconds` - Uptime calculation
- `up{job="prometheus-prometheus-node-exporter"}` - Node availability

### From Kube State Metrics:
- `kube_pod_status_phase` - Pod states
- `kube_deployment_status_replicas` - Deployment replicas
- `kube_node_status_condition` - Node conditions

### From Custom Metrics App:
- `http_requests_total` - Total HTTP requests
- `http_errors_total` - Total errors
- `http_request_duration_seconds` - Request duration histogram
- `http_active_connections` - Current active connections

---

## 🔔 Alert Rules Summary

| Alert Name | Threshold | Duration | Severity | Description |
|------------|-----------|----------|----------|-------------|
| HighErrorRate | > 10 errors/sec | 2m | warning | High error rate from metrics app |
| HighRequestRate | > 100 req/sec | 5m | info | High request rate (informational) |
| SlowResponseTime | p95 > 2s | 5m | warning | Response time degradation |
| HighCPUUsage | > 80% | 5m | warning | Node CPU usage high |
| HighMemoryUsage | > 85% | 5m | warning | Node memory usage high |
| HighTemperature | > 75°C | 5m | warning | Raspberry Pi overheating |
| NodeDown | up == 0 | 1m | **critical** | Node Exporter unreachable |
| DiskSpaceRunningLow | < 15% free | 5m | warning | Running out of disk space |

---

## 📝 Next Steps

### Recommended Improvements:
1. **Configure Email/Slack notifications** - Update AlertManager receivers
2. **Tune alert thresholds** - Adjust based on your actual usage patterns
3. **Add more alert rules** - Monitor batch job success rates, log error rates
4. **Create alert runbooks** - Document how to respond to each alert
5. **Set up on-call rotation** - Use PagerDuty integration for critical alerts

### Optional Enhancements:
- **Grafana Alerting**: Create alerts directly in Grafana (alternative to Prometheus rules)
- **Alert inhibition**: Prevent alert storms during incidents
- **Recording rules**: Pre-calculate expensive queries for faster dashboards
- **Long-term metrics storage**: Use Thanos or Cortex for metrics beyond 2 days

---

## 🎉 Summary

You now have a **production-grade observability stack** running on your Raspberry Pi cluster:

✅ **Metrics**: Prometheus collecting from Node Exporter, Kube State Metrics, and custom apps
✅ **Logs**: Loki aggregating logs from all pods via Promtail
✅ **Visualization**: Grafana with 3 comprehensive dashboards
✅ **Alerting**: AlertManager routing alerts to webhooks (easy to add email/Slack)
✅ **Monitoring**: Real-time hardware monitoring (CPU, memory, disk, network, temperature)

All managed through **GitOps** - just commit to Git and Flux deploys automatically!

---

**Created**: 2026-01-06
**Components**: AlertManager, Node Exporter, Alert Webhook, 8 Alert Rules, New Grafana Dashboard
**Cluster**: 2x Raspberry Pi (ARMv7)
