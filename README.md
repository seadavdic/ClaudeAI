# Raspberry Pi Kubernetes Homelab

A complete production-grade Kubernetes homelab running on Raspberry Pi with GitOps, monitoring, logging, and real-world applications.

## 🎯 What's Inside

This repository contains a fully functional Kubernetes cluster with:

### 🏗️ Infrastructure
- **k3s Kubernetes** (v1.34.3) on 2x Raspberry Pi 4B (ARMv7)
- **Flux CD** - GitOps continuous deployment
- **Traefik** - Ingress controller with hostname-based routing
- **MetalLB** - LoadBalancer (IP pool: 192.168.178.210-230)
- **Cloudflare Tunnel** - Secure public access without port forwarding

### 📊 Observability Stack
- **Prometheus** - Metrics collection & alerting
- **Grafana** - Dashboards & visualization
- **Loki** - Log aggregation & storage
- **Promtail** - Log collection agent
- **AlertManager** - Alert routing & notifications

### 🏪 Applications
- **SmartBiz** - Full-stack business management app
  - PostgreSQL 15 database
  - FastAPI backend with CRUD operations
  - Single-page application UI
  - Stock management system
  - Business metrics & Grafana dashboards
  - Public access via Cloudflare Tunnel

### 🧪 Demo Applications
- **Metrics Generator** - Python app generating web server metrics
- **Log Generator** - Multi-level structured logging demo
- **REST API** - Flask API with rich logging
- **Batch Jobs** - CronJob simulator

## 🚀 Quick Start

### Prerequisites
- 2x Raspberry Pi 4B (ARMv7)
- Raspbian GNU/Linux 10 (Buster)
- Static IPs configured (192.168.178.100, 192.168.178.101)

### Installation

1. **Set up the cluster:**
   ```bash
   cd k3s-setup/scripts
   sudo bash 00-prerequisites.sh  # Run on both nodes
   sudo bash 01-install-master.sh  # Run on master
   sudo bash 02-install-worker.sh  # Run on worker
   sudo bash 03-verify-cluster.sh  # Verify installation
   ```

2. **Bootstrap Flux CD:**
   ```bash
   flux bootstrap github \
     --owner=yourname \
     --repository=ClaudeAI \
     --path=clusters/my-cluster \
     --personal
   ```

3. **Deploy applications:**
   ```bash
   # All apps auto-deploy via GitOps!
   # Just commit to Git and Flux handles the rest
   git add apps/
   git commit -m "Add new app"
   git push
   ```

## 🌐 Access Points

### Local Access (requires hosts file configuration)
- **Grafana:** http://grafana.local:30683
- **Prometheus:** http://prometheus.local:30683
- **SmartBiz:** http://smartbiz.local:30683
- **AlertManager:** http://alertmanager.local:30683

### External Access (Cloudflare Tunnel)
- **SmartBiz:** https://leslie-shortcuts-jokes-cart.trycloudflare.com
- **Grafana:** (configure your own tunnel)

### Hosts File Configuration
Add to `C:\Windows\System32\drivers\etc\hosts`:
```
192.168.178.100 grafana.local
192.168.178.100 prometheus.local
192.168.178.100 smartbiz.local
192.168.178.100 api.local
192.168.178.100 alertmanager.local
```

## 📚 Documentation

- **[Architecture Overview](ARCHITECTURE.md)** - Complete system architecture with diagrams
- **[Installation Guide](docs/INSTALLATION-GUIDE.md)** - k3s cluster setup
- **[SmartBiz Application](docs/SMARTBIZ.md)** - Full-stack app documentation
- **[Loki Setup](docs/LOKI-SETUP-SUMMARY.md)** - Log aggregation configuration
- **[AlertManager Setup](docs/ALERTMANAGER-SETUP-SUMMARY.md)** - Alerting configuration

## 📁 Repository Structure

```
.
├── apps/                          # Application deployments (GitOps)
│   ├── grafana/                   # Grafana + dashboards
│   ├── prometheus/                # Prometheus + scrape configs
│   ├── loki/                      # Loki log aggregation
│   ├── metallb/                   # LoadBalancer
│   ├── cloudflared/               # Cloudflare Tunnel
│   ├── smartbiz-db/               # PostgreSQL database
│   ├── smartbiz-api/              # FastAPI backend
│   ├── smartbiz-ui/               # Nginx + SPA frontend
│   ├── metrics-app/               # Demo metrics app
│   ├── log-generator/             # Demo logging app
│   ├── rest-api/                  # Demo REST API
│   └── batch-job/                 # Demo CronJob
│
├── clusters/my-cluster/           # Flux CD configuration
│   └── flux-system/               # Flux controllers
│
├── k3s-setup/                     # Installation scripts
│   └── scripts/                   # Cluster setup scripts
│
├── docs/                          # Documentation
│   ├── SMARTBIZ.md               # SmartBiz app guide
│   ├── INSTALLATION-GUIDE.md     # Cluster installation
│   ├── LOKI-SETUP-SUMMARY.md     # Logging setup
│   └── ALERTMANAGER-SETUP-SUMMARY.md  # Alerting setup
│
├── ARCHITECTURE.md                # System architecture
└── README.md                      # This file
```

## 🛠️ Technologies

- **Kubernetes:** k3s v1.34.3
- **Container Runtime:** containerd v2.1.5-k3s1
- **GitOps:** Flux CD v2.x
- **Ingress:** Traefik
- **Storage:** local-path provisioner
- **Monitoring:** Prometheus + Grafana
- **Logging:** Loki + Promtail
- **Databases:** PostgreSQL 15 Alpine
- **Backend:** FastAPI (Python 3.9)
- **Frontend:** Vanilla JavaScript + Nginx
- **Public Access:** Cloudflare Tunnel

## 🎓 Key Features

- ✅ **GitOps Automation** - All deployments via Git commits
- ✅ **Complete Observability** - Metrics, logs, and traces
- ✅ **Production-Ready** - Persistent storage, probes, resource limits
- ✅ **Secure Public Access** - No port forwarding required
- ✅ **ARM32 Compatible** - Optimized for Raspberry Pi ARMv7
- ✅ **Auto-Healing** - Kubernetes self-healing capabilities
- ✅ **Monitoring Alerts** - Prometheus AlertManager integration
- ✅ **Business Metrics** - Real-time KPIs in Grafana

## 📈 System Stats

- **Cluster Nodes:** 2x Raspberry Pi 4B
- **Running Pods:** ~30+ across 8 namespaces
- **Applications Deployed:** 15+
- **Metrics Collected:** 50+ time-series
- **Log Streams:** All pods
- **Uptime:** High availability with pod restart policies

## 🤝 Contributing

This is a personal homelab project, but feel free to use it as inspiration for your own setup!

## 📝 License

MIT License

---

**Created:** 2026-01-04
**Last Updated:** 2026-01-07
**Cluster:** 2x Raspberry Pi (ARMv7)
**GitOps:** Flux CD
**Monitoring:** Prometheus + Grafana + Loki
**Applications:** SmartBiz (PostgreSQL + FastAPI + SPA)
