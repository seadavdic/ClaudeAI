# Grafana Dashboards Documentation

This document provides comprehensive documentation for all Grafana dashboards deployed in the Kubernetes cluster.

## 📊 Dashboard Overview

The cluster includes **6 production-ready dashboards** for comprehensive monitoring:

| Dashboard | Purpose | Update Interval | Use Case |
|-----------|---------|-----------------|----------|
| **SmartBiz Business Metrics** | Business KPIs tracking | 30s | Monitor business performance |
| **RabbitMQ & Order Pipeline** | Event-driven microservices | 10s | Track message flow and processing |
| **Flux GitOps Status** | GitOps deployment health | 30s | Monitor CI/CD pipeline |
| **Web Server Metrics** | HTTP request monitoring | 30s | Track web server performance |
| **Observability Complete** | Application observability | 30s | Monitor application metrics |
| **Cluster Monitoring** | System resource usage | 30s | Track infrastructure health |

## 🔐 Accessing Dashboards

```bash
# Access Grafana
http://grafana.local:30683

# Credentials
Username: admin
Password: See docs/SEALED-SECRETS.md
```

---

## 1. SmartBiz Business Metrics

**Purpose:** Real-time business performance monitoring and KPI tracking

**Tags:** `smartbiz`, `business`
**Refresh Rate:** 30 seconds

### Panels

#### Top Row - Key Business Metrics
1. **Total Articles** (Stat)
   - Metric: `smartbiz_articles_total`
   - Shows: Total number of articles in the system
   - Color: Blue
   - Visual: Value with area graph

2. **Total Customers** (Stat)
   - Metric: `smartbiz_customers_total`
   - Shows: Total registered customers
   - Color: Green
   - Visual: Value with area graph

3. **Total Orders** (Stat)
   - Metric: `smartbiz_orders_total`
   - Shows: Cumulative order count
   - Color: Orange
   - Visual: Value with area graph

4. **Total Revenue** (Stat)
   - Metric: `smartbiz_revenue_total`
   - Shows: Total revenue generated
   - Color: Purple
   - Visual: Value with area graph

#### Second Row - Time Series
5. **Order Rate (per minute)** (Time Series)
   - Metric: `rate(smartbiz_orders_total[1m]) * 60`
   - Shows: Orders placed per minute
   - Visual: Line graph with smooth interpolation
   - Unit: Orders per minute

6. **Revenue Rate (per minute)** (Time Series)
   - Metric: `rate(smartbiz_revenue_total[1m]) * 60`
   - Shows: Revenue generation rate
   - Visual: Line graph with smooth interpolation
   - Unit: Currency per minute

### Use Cases
- **Business Monitoring:** Track real-time business performance
- **Growth Tracking:** Monitor customer and order growth trends
- **Revenue Analysis:** Analyze revenue generation patterns
- **Capacity Planning:** Identify peak business hours

---

## 2. RabbitMQ & Order Pipeline

**Purpose:** Monitor event-driven microservices and message queue health

**Tags:** `rabbitmq`, `order-pipeline`, `messaging`
**Refresh Rate:** 10 seconds
**Time Range:** Last 15 minutes

### Sections

#### RabbitMQ Overview
1. **Total Queued Messages** (Stat)
   - Metric: `sum(rabbitmq_queue_messages)`
   - Shows: Total messages across all queues
   - Thresholds:
     - Green: 0-99
     - Yellow: 100-999
     - Red: 1000+
   - Visual: Background color changes with load

2. **Messages Ready** (Stat)
   - Metric: `sum(rabbitmq_queue_messages_ready)`
   - Shows: Messages waiting to be processed
   - Color: Blue
   - Visual: Value with area graph

3. **Messages Unacknowledged** (Stat)
   - Metric: `sum(rabbitmq_queue_messages_unacked)`
   - Shows: Messages currently being processed
   - Thresholds:
     - Green: 0-49
     - Yellow: 50-199
     - Red: 200+

4. **Consumer Count** (Stat)
   - Metric: `sum(rabbitmq_queue_consumers)`
   - Shows: Active message consumers
   - Thresholds:
     - Red: 0 (no consumers)
     - Yellow: 1-2
     - Green: 3+

#### Message Flow Visualization
5. **Message Queue Depth Over Time** (Time Series)
   - Metric: `rabbitmq_queue_messages` per queue
   - Shows: Message depth per queue
   - Legend: Queue names
   - Visual: Stacked area chart

6. **Message Publish Rate** (Time Series)
   - Metric: `rate(rabbitmq_queue_messages_published_total[1m])`
   - Shows: Messages published per minute
   - Visual: Line graph

7. **Message Delivery Rate** (Time Series)
   - Metric: `rate(rabbitmq_queue_messages_delivered_total[1m])`
   - Shows: Messages delivered per minute
   - Visual: Line graph

#### Order Pipeline Microservices
8. **Order Processing Status** (Stat Row)
   - Shows: Status of each microservice
   - Services:
     - Order Generator
     - Inventory Service
     - Fulfillment Service
     - Notification Service

9. **Service Processing Times** (Time Series)
   - Metric: `rate(service_processing_duration_seconds_sum[5m]) / rate(service_processing_duration_seconds_count[5m])`
   - Shows: Average processing time per service
   - Unit: Seconds
   - Visual: Multi-line graph

10. **Error Rates by Service** (Time Series)
    - Metric: `rate(service_errors_total[5m])`
    - Shows: Errors per minute by service
    - Visual: Line graph with error highlighting

### Use Cases
- **Queue Health:** Monitor message queue depth and prevent backlogs
- **Consumer Monitoring:** Ensure all queues have active consumers
- **Throughput Analysis:** Track message publish/delivery rates
- **Service Health:** Monitor microservice processing times and errors
- **Bottleneck Detection:** Identify slow services in the pipeline

---

## 3. Flux GitOps Status

**Purpose:** Monitor GitOps continuous deployment pipeline health

**Tags:** `flux`, `gitops`, `kubernetes`
**Refresh Rate:** 30 seconds

**Note:** This dashboard is compatible with Flux CD v1.7.3 and uses `gotk_reconcile_duration_seconds` metrics.

### Panels

#### Top Row - Resource Counts
1. **Active Kustomizations** (Stat)
   - Metric: `count(count by (name, namespace) (gotk_reconcile_duration_seconds_count{kind="Kustomization"}))`
   - Shows: Number of Kustomization resources being reconciled
   - Thresholds:
     - Red: 0 (nothing deployed)
     - Green: 1+
   - Current: 2 active

2. **Active HelmReleases** (Stat)
   - Metric: `count(count by (name, namespace) (gotk_reconcile_duration_seconds_count{kind="HelmRelease"}))`
   - Shows: Number of Helm charts being managed
   - Thresholds:
     - Red: 0
     - Green: 1+
   - Current: 5 active (Grafana, Prometheus, Loki, etc.)

3. **Active GitRepositories** (Stat)
   - Metric: `count(count by (name, namespace) (gotk_reconcile_duration_seconds_count{kind="GitRepository"}))`
   - Shows: Number of Git repositories being monitored
   - Thresholds:
     - Red: 0
     - Green: 1+

4. **Total Reconciliations (5m)** (Stat)
   - Metric: `sum(increase(gotk_reconcile_duration_seconds_count[5m]))`
   - Shows: Total reconciliation activity in last 5 minutes
   - Color: Blue
   - Visual: Value with area graph showing activity

#### Middle Row - Performance Metrics
5. **Reconciliation Duration (seconds)** (Time Series)
   - Metric: `sum by (kind) (rate(gotk_reconcile_duration_seconds_sum[5m]) / rate(gotk_reconcile_duration_seconds_count[5m]))`
   - Shows: Average reconciliation time by resource type
   - Unit: Seconds
   - Visual: Multi-line graph by resource kind (Kustomization, HelmRelease, GitRepository)

6. **Reconciliation Rate (per minute)** (Time Series)
   - Metric: `sum by (kind) (rate(gotk_reconcile_duration_seconds_count[1m]) * 60)`
   - Shows: Reconciliations per minute by resource type
   - Unit: Operations per minute
   - Visual: Multi-line graph showing activity rate

#### Resources Table
7. **Flux Resources Activity** (Table)
   - Metric: `sum by (kind, name, namespace) (gotk_reconcile_duration_seconds_count)`
   - Columns:
     - Resource Type (kind)
     - Name
     - Namespace
     - Total Reconciliations (lifetime count)
   - Sort: By Resource Type
   - Shows: All Flux resources with reconciliation activity

#### Bottom Row - Health Metrics
8. **Flux Controllers Status** (Stat)
   - Metric: `count(up{job="kubernetes-pods", namespace="flux-system", app=~".*-controller"})`
   - Shows: Number of running Flux controllers
   - Thresholds:
     - Red: 0-2
     - Yellow: 3
     - Green: 4 (all controllers running)
   - Controllers: source, kustomize, helm, notification

9. **Reconciliation Activity** (Stat)
   - Metric: `sum(rate(gotk_reconcile_duration_seconds_count[1m]) * 60)`
   - Shows: Current reconciliation rate per minute
   - Color: Blue
   - Visual: Value with area graph

10. **Avg Reconciliation Time** (Stat)
    - Metric: `avg(rate(gotk_reconcile_duration_seconds_sum[5m]) / rate(gotk_reconcile_duration_seconds_count[5m]))`
    - Shows: Average time to reconcile resources
    - Thresholds:
      - Green: 0-2s
      - Yellow: 2-5s
      - Red: 5s+
    - Visual: Background color shows performance

### Use Cases
- **Deployment Monitoring:** Track GitOps deployments in real-time
- **Resource Health:** Monitor all Flux-managed resources
- **Performance Tracking:** Identify slow reconciliations
- **Controller Status:** Ensure all Flux controllers are running
- **Activity Monitoring:** Track reconciliation frequency

### Troubleshooting with This Dashboard

**Problem:** Git commit not deploying
1. Check **Active GitRepositories** - Should be 1+
2. Check **Active Kustomizations** - Should show your apps
3. Look at **Resources Activity** table for specific resource

**Problem:** Slow deployments
1. Check **Reconciliation Duration** - Look for spikes
2. Check **Avg Reconciliation Time** - Should be under 2s
3. Identify slow resource in **Resources Activity** table

**Problem:** Controllers not working
1. Check **Flux Controllers Status** - Should be 4
2. If less than 4, check pod status in Kubernetes

For detailed troubleshooting, see [docs/FLUX-DASHBOARD.md](FLUX-DASHBOARD.md)

---

## 4. Web Server Metrics

**Purpose:** Monitor HTTP request processing and web server performance

**Tags:** `metrics-app`, `web-server`
**Refresh Rate:** 30 seconds

### Panels

#### Top Row - Request Metrics
1. **Total HTTP Requests (Last 10min)** (Stat)
   - Metric: `sum(increase(http_requests_total[10m]))`
   - Shows: Total HTTP requests in last 10 minutes
   - Thresholds:
     - Green: 0-999
     - Yellow: 1000-4999
     - Red: 5000+
   - Visual: Value with area graph

2. **Active Connections (Gauge)** (Gauge)
   - Metric: `http_active_connections`
   - Shows: Current active HTTP connections
   - Range: 0-100
   - Thresholds:
     - Green: 0-49
     - Yellow: 50-79
     - Red: 80+
   - Visual: Gauge dial

3. **Request Rate (per minute)** (Stat)
   - Metric: `rate(http_requests_total[1m]) * 60`
   - Shows: Requests per minute
   - Visual: Value with graph

4. **Average Response Time** (Stat)
   - Metric: `rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m])`
   - Shows: Average response time
   - Unit: Seconds
   - Thresholds:
     - Green: <0.1s
     - Yellow: 0.1-0.5s
     - Red: >0.5s

#### Middle Row - Performance Analysis
5. **Response Time Percentiles** (Time Series)
   - Metrics:
     - p50: `histogram_quantile(0.50, sum by(le) (rate(http_request_duration_seconds_bucket[5m])))`
     - p95: `histogram_quantile(0.95, sum by(le) (rate(http_request_duration_seconds_bucket[5m])))`
     - p99: `histogram_quantile(0.99, sum by(le) (rate(http_request_duration_seconds_bucket[5m])))`
   - Shows: Response time distribution
   - Unit: Seconds
   - Visual: Three-line graph (median, 95th, 99th percentile)

6. **Error Rate by Type** (Time Series)
   - Metric: `sum by (status_code) (rate(http_requests_total{status_code=~"4..|5.."}[5m]))`
   - Shows: Error requests per second by status code
   - Visual: Stacked area by HTTP status code
   - Filters: 4xx and 5xx errors only

#### Bottom Row - Traffic Patterns
7. **Requests by Endpoint** (Time Series)
   - Metric: `sum by (endpoint) (rate(http_requests_total[5m]))`
   - Shows: Request rate per endpoint
   - Visual: Multi-line graph per endpoint
   - Legend: Endpoint paths

8. **HTTP Status Code Distribution** (Pie Chart)
   - Metric: `sum by (status_code) (increase(http_requests_total[10m]))`
   - Shows: Distribution of HTTP status codes
   - Visual: Pie chart with percentages
   - Segments: 2xx, 3xx, 4xx, 5xx

### Use Cases
- **Performance Monitoring:** Track response times and identify slowdowns
- **Capacity Planning:** Monitor active connections and request rates
- **Error Detection:** Identify and track 4xx/5xx errors
- **Traffic Analysis:** Understand endpoint usage patterns
- **SLA Monitoring:** Track p95/p99 response times

---

## 5. Observability Complete

**Purpose:** Comprehensive application observability and metrics monitoring

**Tags:** `observability`, `application`
**Refresh Rate:** 30 seconds

### Panels

#### Application Health
1. **Application Status** (Stat)
   - Metric: `up{job="application"}`
   - Shows: Application availability
   - Mappings:
     - 1 = UP (Green)
     - 0 = DOWN (Red)

2. **Total Events Processed** (Stat)
   - Metric: `sum(events_processed_total)`
   - Shows: Cumulative event count
   - Visual: Value with area graph

3. **Events Processing Rate** (Time Series)
   - Metric: `rate(events_processed_total[5m])`
   - Shows: Events processed per second
   - Visual: Line graph

#### Performance Metrics
4. **CPU Usage** (Gauge)
   - Metric: `process_cpu_seconds_total`
   - Shows: CPU utilization percentage
   - Range: 0-100%
   - Thresholds:
     - Green: 0-60%
     - Yellow: 60-80%
     - Red: 80-100%

5. **Memory Usage** (Gauge)
   - Metric: `process_resident_memory_bytes / 1024 / 1024`
   - Shows: Memory usage in MB
   - Visual: Gauge dial

6. **Cache Hit Rate** (Time Series)
   - Metric: `rate(cache_hits_total[5m]) / (rate(cache_hits_total[5m]) + rate(cache_misses_total[5m]))`
   - Shows: Cache effectiveness (0-1 scale)
   - Visual: Line graph
   - Unit: Percentage

#### Business Metrics
7. **Active Users** (Stat)
   - Metric: `active_users`
   - Shows: Current active user count
   - Color: Green

8. **Session Duration** (Time Series)
   - Metric: `histogram_quantile(0.95, sum by(le) (rate(session_duration_seconds_bucket[5m])))`
   - Shows: 95th percentile session duration
   - Unit: Seconds

### Use Cases
- **Application Health:** Monitor overall app availability
- **Performance Tuning:** Track CPU and memory usage
- **Cache Optimization:** Monitor cache effectiveness
- **User Monitoring:** Track active users and session patterns

---

## 6. Cluster Monitoring

**Purpose:** Kubernetes infrastructure and resource monitoring

**Tags:** `kubernetes`, `infrastructure`, `resources`
**Refresh Rate:** 30 seconds

### Panels

#### Cluster Overview
1. **Total Nodes** (Stat)
   - Metric: `count(kube_node_info)`
   - Shows: Number of cluster nodes
   - Color: Blue
   - Current: 2 nodes (k3s-master, k3s-worker-1)

2. **Total Pods** (Stat)
   - Metric: `count(kube_pod_info)`
   - Shows: Total running pods
   - Color: Green

3. **Pod Status** (Stat Row)
   - Running: `count(kube_pod_status_phase{phase="Running"})`
   - Pending: `count(kube_pod_status_phase{phase="Pending"})`
   - Failed: `count(kube_pod_status_phase{phase="Failed"})`

#### Node Resources
4. **CPU Usage by Node** (Time Series)
   - Metric: `100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)`
   - Shows: CPU usage percentage per node
   - Unit: Percentage
   - Visual: Multi-line graph per node

5. **Memory Usage by Node** (Time Series)
   - Metric: `(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100`
   - Shows: Memory usage percentage per node
   - Unit: Percentage
   - Visual: Multi-line graph per node

6. **Disk Usage by Node** (Gauge)
   - Metric: `(node_filesystem_size_bytes{mountpoint="/"} - node_filesystem_avail_bytes{mountpoint="/"}) / node_filesystem_size_bytes{mountpoint="/"} * 100`
   - Shows: Root filesystem usage
   - Range: 0-100%
   - Thresholds:
     - Green: 0-70%
     - Yellow: 70-85%
     - Red: 85-100%

#### Pod Resources
7. **Pod CPU Usage (Top 10)** (Table)
   - Metric: `topk(10, sum by (pod, namespace) (rate(container_cpu_usage_seconds_total[5m])))`
   - Shows: Top 10 CPU-consuming pods
   - Columns: Pod, Namespace, CPU Usage

8. **Pod Memory Usage (Top 10)** (Table)
   - Metric: `topk(10, sum by (pod, namespace) (container_memory_working_set_bytes / 1024 / 1024))`
   - Shows: Top 10 memory-consuming pods
   - Columns: Pod, Namespace, Memory (MB)

#### Network
9. **Network Traffic** (Time Series)
   - Receive: `rate(node_network_receive_bytes_total[5m])`
   - Transmit: `rate(node_network_transmit_bytes_total[5m])`
   - Shows: Network throughput
   - Unit: Bytes per second
   - Visual: Two-line graph (RX/TX)

10. **Pod Restarts** (Time Series)
    - Metric: `sum by (pod, namespace) (increase(kube_pod_container_status_restarts_total[1h]))`
    - Shows: Pod restart count in last hour
    - Visual: Bar graph

### Use Cases
- **Infrastructure Monitoring:** Track node and pod health
- **Capacity Planning:** Monitor resource usage trends
- **Performance Troubleshooting:** Identify resource-intensive pods
- **Reliability:** Track pod restarts and failures
- **Network Monitoring:** Analyze cluster network traffic

---

## 🎯 Dashboard Selection Guide

Choose the right dashboard for your monitoring needs:

| What to Monitor | Use This Dashboard |
|-----------------|-------------------|
| Business performance, revenue, orders | **SmartBiz Business Metrics** |
| Message queues, microservices, event processing | **RabbitMQ & Order Pipeline** |
| GitOps deployments, Flux resources, CI/CD | **Flux GitOps Status** |
| Web server requests, response times, HTTP errors | **Web Server Metrics** |
| Application metrics, cache, user sessions | **Observability Complete** |
| Kubernetes nodes, pods, CPU, memory | **Cluster Monitoring** |

## 🔧 Dashboard Maintenance

### Updating Dashboards

Dashboards are defined in `apps/grafana/dashboard-configmap.yaml` and deployed via Flux GitOps:

```bash
# 1. Edit dashboard JSON in dashboard-configmap.yaml
vim apps/grafana/dashboard-configmap.yaml

# 2. Commit changes
git add apps/grafana/dashboard-configmap.yaml
git commit -m "Update dashboard: <description>"
git push

# 3. Flux automatically deploys changes
# Grafana reloads dashboards within 30 seconds

# 4. Verify in Grafana UI
# Dashboard changes appear automatically
```

### Adding New Dashboards

1. Create dashboard JSON definition in `dashboard-configmap.yaml`
2. Add entry to this documentation
3. Update README.md dashboard list
4. Commit and push to Git
5. Flux deploys automatically

### Troubleshooting Dashboards

**No Data in Panels:**
1. Check Prometheus is scraping metrics: `http://prometheus.local:30690/targets`
2. Verify metric exists in Prometheus: Query metric name in Prometheus UI
3. Check time range in dashboard (some queries use 5m, 10m windows)
4. Verify pods exposing metrics are running

**Dashboard Not Appearing:**
1. Check ConfigMap is deployed: `kubectl get cm -n grafana`
2. Check Grafana logs: `kubectl logs -n grafana deployment/grafana-grafana -f`
3. Verify JSON syntax is valid
4. Restart Grafana: `kubectl rollout restart deployment/grafana-grafana -n grafana`

## 📊 Metrics Reference

### Common Metric Patterns

**Counter Metrics** (always increasing):
- `http_requests_total`
- `smartbiz_orders_total`
- `gotk_reconcile_duration_seconds_count`
- Use with `rate()` or `increase()` for meaningful values

**Gauge Metrics** (can go up or down):
- `http_active_connections`
- `rabbitmq_queue_messages`
- `active_users`
- Display directly without rate calculation

**Histogram Metrics** (for percentiles):
- `http_request_duration_seconds_bucket`
- `session_duration_seconds_bucket`
- Use with `histogram_quantile()` for p50, p95, p99

### PromQL Functions Reference

```promql
# Rate (per-second rate over time window)
rate(http_requests_total[5m])

# Increase (total increase over time window)
increase(http_requests_total[10m])

# Sum (aggregate across labels)
sum(rabbitmq_queue_messages)
sum by (endpoint) (http_requests_total)

# Percentiles
histogram_quantile(0.95, sum by(le) (rate(http_request_duration_seconds_bucket[5m])))

# Average
avg(rate(gotk_reconcile_duration_seconds_sum[5m]) / rate(gotk_reconcile_duration_seconds_count[5m]))
```

## 🔗 Related Documentation

- [SEALED-SECRETS.md](SEALED-SECRETS.md) - Grafana credentials
- [FLUX-DASHBOARD.md](FLUX-DASHBOARD.md) - Detailed Flux dashboard guide
- [CLUSTER-OVERVIEW.md](CLUSTER-OVERVIEW.md) - Cluster architecture
- [ARCHITECTURE.md](../ARCHITECTURE.md) - System architecture diagrams

---

**Last Updated:** 2026-01-08
**Grafana Version:** 10.5.4
**Prometheus Version:** 28.2.1
**Flux CD Version:** v1.7.3
