# Raspberry Pi Kubernetes Cluster

A production-grade Kubernetes cluster running on Raspberry Pi hardware with GitOps (Flux CD), complete monitoring stack, and secure secrets management.

## 📚 Documentation

All project documentation is located in the **[docs/](docs/)** folder:

- **[CLUSTER-OVERVIEW.md](docs/CLUSTER-OVERVIEW.md)** - Complete cluster overview and access points
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Detailed architecture diagrams and technical design
- **[INSTALLATION-GUIDE.md](docs/INSTALLATION-GUIDE.md)** - Step-by-step installation instructions
- **[SEALED-SECRETS.md](docs/SEALED-SECRETS.md)** - Secrets management guide
- **[SMARTBIZ.md](docs/SMARTBIZ.md)** - SmartBiz application documentation
- **[RABBITMQ-PIPELINE.md](docs/RABBITMQ-PIPELINE.md)** - Order processing pipeline
- **[LOKI-SETUP-SUMMARY.md](docs/LOKI-SETUP-SUMMARY.md)** - Logging stack setup
- **[ALERTMANAGER-SETUP-SUMMARY.md](docs/ALERTMANAGER-SETUP-SUMMARY.md)** - Alerting configuration

## 🚀 Quick Start

```bash
# Access your cluster
kubectl get pods -A

# View Grafana dashboards
http://grafana.local:30683
```

## 🔐 Security Features

✅ **Sealed Secrets** - Encrypted credentials in Git
✅ **GitOps** - Automated deployments via Flux CD
✅ **ARM32 Compatible** - Optimized for Raspberry Pi

---

**Start here:** [docs/CLUSTER-OVERVIEW.md](docs/CLUSTER-OVERVIEW.md)
