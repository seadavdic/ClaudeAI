#!/bin/bash

###############################################################################
# Kubernetes Cluster Setup - Prerequisites
# Script to prepare Raspberry Pi for Kubernetes (k3s) installation
# Run this on BOTH master and worker nodes
###############################################################################

set -e

echo "======================================"
echo "Kubernetes Prerequisites Setup"
echo "======================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run as root (use sudo)"
    exit 1
fi

# Get node information
echo "Current hostname: $(hostname)"
read -p "Is this the MASTER node? (y/n): " is_master
echo ""

# Update system
echo "[1/7] Updating system packages..."
apt-get update
apt-get upgrade -y
echo "✓ System updated"
echo ""

# Disable swap (Kubernetes requirement)
echo "[2/7] Disabling swap..."
dphys-swapfile swapoff || true
dphys-swapfile uninstall || true
systemctl disable dphys-swapfile || true
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab
echo "✓ Swap disabled"
echo ""

# Enable cgroup (required for k3s)
echo "[3/7] Enabling cgroup in boot config..."
if ! grep -q "cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory" /boot/cmdline.txt; then
    cp /boot/cmdline.txt /boot/cmdline.txt.backup
    sed -i '$ s/$/ cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory/' /boot/cmdline.txt
    echo "✓ cgroup enabled (requires reboot)"
else
    echo "✓ cgroup already enabled"
fi
echo ""

# Install required packages
echo "[4/7] Installing required packages..."
apt-get install -y \
    curl \
    wget \
    git \
    ca-certificates \
    gnupg \
    lsb-release \
    iptables \
    ipset
echo "✓ Packages installed"
echo ""

# Enable IP forwarding
echo "[5/7] Enabling IP forwarding..."
cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF
sysctl --system
echo "✓ IP forwarding enabled"
echo ""

# Configure iptables
echo "[6/7] Configuring iptables..."
update-alternatives --set iptables /usr/sbin/iptables-legacy || true
update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy || true
echo "✓ iptables configured"
echo ""

# Set static hostname (optional but recommended)
echo "[7/7] Configuring hostname..."
if [ "$is_master" = "y" ] || [ "$is_master" = "Y" ]; then
    read -p "Set hostname to 'k3s-master'? (y/n): " set_hostname
    if [ "$set_hostname" = "y" ] || [ "$set_hostname" = "Y" ]; then
        hostnamectl set-hostname k3s-master
        echo "✓ Hostname set to k3s-master"
    fi
else
    read -p "Set hostname to 'k3s-worker-1'? (y/n): " set_hostname
    if [ "$set_hostname" = "y" ] || [ "$set_hostname" = "Y" ]; then
        hostnamectl set-hostname k3s-worker-1
        echo "✓ Hostname set to k3s-worker-1"
    fi
fi
echo ""

# Summary
echo "======================================"
echo "Prerequisites Setup Complete!"
echo "======================================"
echo ""
echo "IMPORTANT: System needs to REBOOT for changes to take effect"
echo ""
echo "After reboot, run:"
if [ "$is_master" = "y" ] || [ "$is_master" = "Y" ]; then
    echo "  - On this MASTER node: sudo bash 01-install-master.sh"
else
    echo "  - On the MASTER node first: sudo bash 01-install-master.sh"
    echo "  - Then on this WORKER node: sudo bash 02-install-worker.sh"
fi
echo ""
read -p "Reboot now? (y/n): " do_reboot
if [ "$do_reboot" = "y" ] || [ "$do_reboot" = "Y" ]; then
    echo "Rebooting in 5 seconds..."
    sleep 5
    reboot
else
    echo "Please reboot manually with: sudo reboot"
fi
