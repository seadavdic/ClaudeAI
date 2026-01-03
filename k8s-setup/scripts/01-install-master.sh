#!/bin/bash

###############################################################################
# Kubernetes Cluster Setup - Master Node
# Script to install k3s on the master/control plane node
# Run this ONLY on the master node AFTER running prerequisites script
###############################################################################

set -e

echo "======================================"
echo "K3s Master Node Installation"
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

# Get master node IP
MASTER_IP=$(hostname -I | awk '{print $1}')
echo "Detected Master IP: $MASTER_IP"
read -p "Is this correct? (y/n): " ip_correct

if [ "$ip_correct" != "y" ] && [ "$ip_correct" != "Y" ]; then
    read -p "Enter the correct IP address: " MASTER_IP
fi
echo ""

# Install k3s on master
echo "[1/3] Installing k3s on master node..."
echo "This may take several minutes..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --bind-address=$MASTER_IP --advertise-address=$MASTER_IP --node-ip=$MASTER_IP --flannel-iface=eth0" sh -

# Wait for k3s to be ready
echo ""
echo "[2/3] Waiting for k3s to be ready..."
sleep 10
systemctl status k3s --no-pager || true

# Wait for node to be ready
echo ""
echo "Waiting for node to be Ready..."
for i in {1..30}; do
    if kubectl get nodes | grep -q "Ready"; then
        echo "✓ Node is Ready!"
        break
    fi
    echo "Waiting... ($i/30)"
    sleep 10
done
echo ""

# Get node token for workers
echo "[3/3] Retrieving node token for worker nodes..."
NODE_TOKEN=$(cat /var/lib/rancher/k3s/server/node-token)

# Create join command file
JOIN_COMMAND_FILE="/root/worker-join-command.sh"
cat > "$JOIN_COMMAND_FILE" <<EOF
#!/bin/bash
# Run this command on worker nodes to join the cluster
curl -sfL https://get.k3s.io | K3S_URL=https://${MASTER_IP}:6443 K3S_TOKEN=${NODE_TOKEN} sh -
EOF
chmod +x "$JOIN_COMMAND_FILE"

echo ""
echo "======================================"
echo "Master Node Installation Complete!"
echo "======================================"
echo ""
echo "Master Node IP: $MASTER_IP"
echo "Node Token saved to: $JOIN_COMMAND_FILE"
echo ""
echo "Cluster Status:"
kubectl get nodes
echo ""
echo "System Pods:"
kubectl get pods -A
echo ""
echo "======================================"
echo "Next Steps:"
echo "======================================"
echo "1. Copy the join command to your worker node:"
echo "   scp $JOIN_COMMAND_FILE pi@<worker-ip>:~/"
echo ""
echo "2. On worker node, run:"
echo "   sudo bash ~/worker-join-command.sh"
echo ""
echo "OR manually run the 02-install-worker.sh script on worker with:"
echo "   Master IP: $MASTER_IP"
echo "   Node Token: $NODE_TOKEN"
echo ""
echo "Useful commands:"
echo "  - kubectl get nodes"
echo "  - kubectl get pods -A"
echo "  - kubectl cluster-info"
echo "======================================"
