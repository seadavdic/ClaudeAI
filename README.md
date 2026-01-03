# ClaudeAI Repository

This repository contains infrastructure and automation scripts for various projects.

## Projects

### 🚀 [Kubernetes Cluster Setup for Raspberry Pi](k8s-setup/)

Automated scripts to set up a lightweight Kubernetes cluster using k3s on Raspberry Pi devices.

**Features:**
- 2-node cluster setup (1 master + 1 worker)
- k3s lightweight Kubernetes distribution
- Automated installation scripts
- Complete verification and troubleshooting tools

**Quick Start:**
```bash
cd k8s-setup/scripts
sudo bash 00-prerequisites.sh  # Run on both nodes
sudo bash 01-install-master.sh  # Run on master
sudo bash 02-install-worker.sh  # Run on worker
```

📖 [Full Documentation](k8s-setup/README.md)

---

## Repository Structure

```
.
├── k8s-setup/           # Kubernetes cluster setup for Raspberry Pi
│   ├── README.md        # Detailed setup guide
│   └── scripts/         # Installation scripts
│       ├── 00-prerequisites.sh
│       ├── 01-install-master.sh
│       ├── 02-install-worker.sh
│       └── 03-verify-cluster.sh
└── README.md            # This file
```

## Contributing

Feel free to contribute improvements or additional automation scripts.

## License

MIT License
