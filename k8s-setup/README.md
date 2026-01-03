# Kubernetes Cluster Setup for Raspberry Pi

This repository contains automated scripts to set up a lightweight Kubernetes cluster using k3s on Raspberry Pi devices.

## Architecture

- **Master Node** (Control Plane): 1x Raspberry Pi
- **Worker Node**: 1x Raspberry Pi
- **Kubernetes Distribution**: k3s (lightweight Kubernetes)

## Prerequisites

### Hardware Requirements
- 2x Raspberry Pi (Model 3B+ or newer recommended)
- MicroSD cards (16GB+ recommended)
- Network connectivity (both Pis on same network)
- Power supplies for both Pis

### Software Requirements
- Raspberry Pi OS Lite (64-bit) or Ubuntu Server ARM64
- SSH access to both Raspberry Pis
- Internet connection

## Installation Steps

### Step 1: Prepare Both Nodes

Run the prerequisites script on **BOTH** the master and worker nodes:

```bash
cd k8s-setup/scripts
chmod +x *.sh
sudo bash 00-prerequisites.sh
```

This script will:
- Update system packages
- Disable swap
- Enable cgroup support
- Install required packages
- Configure networking
- Set hostname

**IMPORTANT**: Reboot both nodes after running this script.

### Step 2: Install Master Node

After rebooting, on the **MASTER** node only:

```bash
sudo bash 01-install-master.sh
```

This script will:
- Install k3s server (control plane)
- Configure the master node
- Generate a node token for workers
- Display cluster status

**Important**: Save the Master IP and Node Token displayed at the end.

### Step 3: Install Worker Node

On the **WORKER** node:

```bash
sudo bash 02-install-worker.sh
```

When prompted, enter:
- Master node IP address
- Node token (from master installation output)

This script will:
- Install k3s agent
- Join the worker to the cluster

### Step 4: Verify Cluster

On the **MASTER** node, verify all nodes are ready:

```bash
kubectl get nodes
```

Expected output:
```
NAME           STATUS   ROLES                  AGE   VERSION
k3s-master     Ready    control-plane,master   5m    v1.28.x+k3s1
k3s-worker-1   Ready    <none>                 2m    v1.28.x+k3s1
```

Check all system pods are running:

```bash
kubectl get pods -A
```

## Useful Commands

### On Master Node

```bash
# View cluster information
kubectl cluster-info

# Get all nodes
kubectl get nodes -o wide

# Get all pods across all namespaces
kubectl get pods -A

# Get services
kubectl get svc -A

# View k3s logs
sudo journalctl -u k3s -f

# Restart k3s
sudo systemctl restart k3s
```

### On Worker Node

```bash
# View k3s agent logs
sudo journalctl -u k3s-agent -f

# Restart k3s agent
sudo systemctl restart k3s-agent

# Check agent status
sudo systemctl status k3s-agent
```

## Deploy a Test Application

Test your cluster with a simple nginx deployment:

```bash
# Create deployment
kubectl create deployment nginx --image=nginx --replicas=2

# Expose as service
kubectl expose deployment nginx --port=80 --type=NodePort

# Check status
kubectl get pods
kubectl get svc nginx

# Get the NodePort
kubectl get svc nginx -o jsonpath='{.spec.ports[0].nodePort}'

# Access nginx at http://<master-or-worker-ip>:<nodeport>
```

## Troubleshooting

### Node Not Ready
```bash
# On master, check node status
kubectl describe node <node-name>

# Check k3s logs
sudo journalctl -u k3s -n 50
```

### Worker Cannot Join
```bash
# Verify network connectivity
ping <master-ip>

# Check if port 6443 is accessible
nc -zv <master-ip> 6443

# Verify token
sudo cat /var/lib/rancher/k3s/server/node-token  # on master
```

### Pods Not Starting
```bash
# Check pod details
kubectl describe pod <pod-name>

# Check pod logs
kubectl logs <pod-name>

# Check node resources
kubectl top nodes  # requires metrics-server
```

## Uninstalling

### On Worker Nodes
```bash
sudo /usr/local/bin/k3s-agent-uninstall.sh
```

### On Master Node
```bash
sudo /usr/local/bin/k3s-uninstall.sh
```

## Network Information

- **Kubernetes API Server**: Port 6443 (master)
- **Flannel Network**: Default CNI for pod networking
- **Service CIDR**: 10.43.0.0/16 (default)
- **Pod CIDR**: 10.42.0.0/16 (default)

## Additional Resources

- [k3s Documentation](https://docs.k3s.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Raspberry Pi Kubernetes Guide](https://www.raspberrypi.com/tutorials/cluster-raspberry-pi-tutorial/)

## Script Overview

| Script | Purpose | Run On |
|--------|---------|--------|
| `00-prerequisites.sh` | System preparation | Both nodes |
| `01-install-master.sh` | Install k3s server | Master only |
| `02-install-worker.sh` | Install k3s agent | Worker only |

## Notes

- k3s is much lighter than full Kubernetes, perfect for Raspberry Pi
- Includes Traefik ingress controller by default
- Built-in local storage provisioner
- Automatic certificate management
- All scripts require root/sudo privileges
- Static IPs recommended for production use
