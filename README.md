# Raspberry Pi Kubernetes Cluster

A production-grade Kubernetes cluster running on Raspberry Pi hardware with GitOps (Flux CD), complete monitoring stack, and secure secrets management.

## 📚 Documentation

All project documentation is located in the **[docs/](docs/)** folder:

- **[CLUSTER-OVERVIEW.md](docs/CLUSTER-OVERVIEW.md)** - Complete cluster overview and access points
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Detailed architecture diagrams and technical design
- **[INSTALLATION-GUIDE.md](docs/INSTALLATION-GUIDE.md)** - Step-by-step installation instructions
- **[GRAFANA-DASHBOARDS.md](docs/GRAFANA-DASHBOARDS.md)** - Complete guide to all 6 dashboards
- **[OAUTH2-GITHUB.md](docs/OAUTH2-GITHUB.md)** - GitHub OAuth authentication setup
- **[CICD-PIPELINE.md](docs/CICD-PIPELINE.md)** - CI/CD with GitHub Actions + Flux Image Automation
- **[NETWORK-POLICIES.md](docs/NETWORK-POLICIES.md)** - Pod-level firewall rules ⭐ NEW!
- **[CERT-MANAGER.md](docs/CERT-MANAGER.md)** - Automatic SSL/TLS certificate management
- **[SEALED-SECRETS.md](docs/SEALED-SECRETS.md)** - Secrets management guide
- **[FLUX-DASHBOARD.md](docs/FLUX-DASHBOARD.md)** - GitOps monitoring dashboard guide
- **[SMARTBIZ.md](docs/SMARTBIZ.md)** - SmartBiz application documentation
- **[RABBITMQ-PIPELINE.md](docs/RABBITMQ-PIPELINE.md)** - Order processing pipeline
- **[LOKI-SETUP-SUMMARY.md](docs/LOKI-SETUP-SUMMARY.md)** - Logging stack setup
- **[ALERTMANAGER-SETUP-SUMMARY.md](docs/ALERTMANAGER-SETUP-SUMMARY.md)** - Alerting configuration

## 🚀 Quick Start

```bash
# Access your cluster
kubectl get pods -A

# View Grafana dashboards (HTTPS enabled + GitHub OAuth)
https://grafana.local:32742
# Authentication: Login with your GitHub account
# CA Trust: See docs/CERT-MANAGER.md
# OAuth Setup: See docs/OAUTH2-GITHUB.md

# Note: HTTP (port 30683) automatically redirects to HTTPS (port 32742)
```

## 📊 Available Dashboards

**6 Production Dashboards** - See [GRAFANA-DASHBOARDS.md](docs/GRAFANA-DASHBOARDS.md) for complete documentation

- **SmartBiz Business Metrics** - Business KPIs, revenue, and order tracking
- **RabbitMQ & Order Pipeline** - Event-driven microservices and message queues
- **Flux GitOps Status** - GitOps deployment health and reconciliation monitoring
- **Web Server Metrics** - HTTP request tracking and performance
- **Observability Complete** - Application observability and cache metrics
- **Cluster Monitoring** - Kubernetes infrastructure and resource usage

## 🔐 Security Features

✅ **Network Policies** - Pod-level firewall rules (namespace isolation)
✅ **OAuth2 Proxy** - GitHub authentication for service access
✅ **Sealed Secrets** - Encrypted credentials in Git (RSA-4096)
✅ **cert-manager** - Automatic SSL/TLS certificates for all services
✅ **HTTPS Everywhere** - All services secured with TLS termination
✅ **GitOps** - Automated deployments via Flux CD
✅ **ARM32 Compatible** - Optimized for Raspberry Pi

## 🚀 CI/CD Pipeline

✅ **GitHub Actions** - Multi-architecture Docker builds (ARM32, ARM64, AMD64)
✅ **GitHub Container Registry** - Container image storage (ghcr.io)
✅ **Flux Image Automation** - Automatic deployments when new images are available
✅ **Semantic Versioning** - Automatic version numbering based on commits

---

**Start here:** [docs/CLUSTER-OVERVIEW.md](docs/CLUSTER-OVERVIEW.md)
