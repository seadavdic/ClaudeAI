#!/bin/bash

###############################################################################
# Kubernetes Cluster Setup - Worker Node
# Script to install k3s agent on worker node and join the cluster
# Run this ONLY on worker nodes AFTER master is installed
###############################################################################

set -e

echo "======================================"
echo "K3s Worker Node Installation"
echo "======================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run as root (use sudo)"
    exit 1
fi

# Verify prerequisites
echo "[Verification] Checking prerequisites..."
if swapon --show | grep -q '/'; then
    echo "ERROR: Swap is still enabled. Please run 00-prerequisites.sh and reboot."
    exit 1
fi

if ! grep -q "cgroup_enable=cpuset" /boot/cmdline.txt; then
    echo "ERROR: cgroup not enabled. Please run 00-prerequisites.sh and reboot."
    exit 1
fi
echo "✓ Prerequisites verified"
echo ""

# Get master node information
echo "You need the following information from the master node:"
echo "  1. Master IP address"
echo "  2. Node token (from /var/lib/rancher/k3s/server/node-token)"
echo ""

read -p "Enter Master Node IP address: " MASTER_IP
if [ -z "$MASTER_IP" ]; then
    echo "ERROR: Master IP is required"
    exit 1
fi

echo ""
read -p "Enter Node Token: " NODE_TOKEN
if [ -z "$NODE_TOKEN" ]; then
    echo "ERROR: Node token is required"
    exit 1
fi

# Test connectivity to master
echo ""
echo "[1/3] Testing connectivity to master node..."
if ping -c 3 "$MASTER_IP" > /dev/null 2>&1; then
    echo "✓ Master node is reachable"
else
    echo "WARNING: Cannot ping master node. Continuing anyway..."
fi
echo ""

# Detect active network interface
echo "Detecting network interface..."
ACTIVE_IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
if [ -z "$ACTIVE_IFACE" ]; then
    # Fallback: find interface with IP assigned
    ACTIVE_IFACE=$(ip -o -4 addr show | grep -v "127.0.0.1" | awk '{print $2}' | head -n1)
fi
echo "Detected active interface: $ACTIVE_IFACE"
echo ""

# Install k3s agent
echo "[2/3] Installing k3s agent and joining cluster..."
echo "This may take several minutes..."
echo "Using network interface: $ACTIVE_IFACE"
curl -sfL https://get.k3s.io | K3S_URL="https://${MASTER_IP}:6443" K3S_TOKEN="$NODE_TOKEN" K3S_NODE_NAME=$(hostname) sh -

# Wait for k3s-agent to be ready
echo ""
echo "[3/3] Waiting for k3s-agent to be ready..."
sleep 10
systemctl status k3s-agent --no-pager || true

echo ""
echo "======================================"
echo "Worker Node Installation Complete!"
echo "======================================"
echo ""
echo "Worker node has joined the cluster at: $MASTER_IP"
echo ""
echo "To verify the node joined successfully, run on the MASTER node:"
echo "  kubectl get nodes"
echo ""
echo "You should see this worker node listed with status 'Ready'"
echo "======================================"
