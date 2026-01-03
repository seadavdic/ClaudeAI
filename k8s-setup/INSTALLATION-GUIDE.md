# Complete Installation Guide - Raspberry Pi Kubernetes Cluster

This guide walks you through the complete process of setting up a Kubernetes cluster on two Raspberry Pis and accessing it from your Windows PC.

## Table of Contents
1. [Hardware Setup](#phase-1-hardware-setup)
2. [Network Configuration](#phase-2-network-configuration)
3. [Cluster Installation](#phase-3-cluster-installation)
4. [Access from Your PC](#phase-4-access-from-your-pc)

---

## Phase 1: Hardware Setup

### What You Need
- 2x Raspberry Pi (3B+ or newer)
- 2x MicroSD cards (16GB+ recommended)
- 2x Power supplies
- Network cables or WiFi connection
- MicroSD card reader for your PC

### Step 1.1: Flash Raspberry Pi OS

**On your Windows PC:**

1. Download [Raspberry Pi Imager](https://www.raspberrypi.com/software/)
2. Insert first MicroSD card
3. Open Raspberry Pi Imager:
   - **OS**: Choose "Raspberry Pi OS Lite (64-bit)"
   - **Storage**: Select your MicroSD card
   - **Settings** (gear icon):
     - ✓ Set hostname: `k3s-master`
     - ✓ Enable SSH (use password authentication)
     - ✓ Set username: `pi`
     - ✓ Set password: (choose a strong password)
     - ✓ Configure WiFi (if using WiFi): enter your SSID and password
     - ✓ Set locale settings
4. Click "Write" and wait for completion
5. Repeat for second SD card with hostname: `k3s-worker-1`

### Step 1.2: Boot Raspberry Pis

1. Insert SD cards into respective Raspberry Pis
2. Connect network cables (or use WiFi configured above)
3. Connect power supplies
4. Wait 2-3 minutes for first boot

---

## Phase 2: Network Configuration

### Step 2.1: Find Raspberry Pi IP Addresses

**Option A: Check your router's DHCP client list**
- Login to your router admin panel
- Look for devices named `k3s-master` and `k3s-worker-1`

**Option B: Use network scanner on Windows**
```powershell
# Download and install Advanced IP Scanner or use:
arp -a
```

**Option C: Use Raspberry Pi Imager's built-in scanner**

Once you find the IPs, note them down:
```
Master IP:  192.168.1.100 (example)
Worker IP:  192.168.1.101 (example)
```

### Step 2.2: Set Static IP Addresses (Recommended)

SSH into each Raspberry Pi and configure static IPs.

**On Master Pi:**
```bash
# SSH from your PC
ssh pi@192.168.1.100

# Edit dhcpcd.conf
sudo nano /etc/dhcpcd.conf

# Add at the end (adjust to your network):
interface eth0
static ip_address=192.168.1.100/24
static routers=192.168.1.1
static domain_name_servers=192.168.1.1 8.8.8.8

# Save (Ctrl+X, Y, Enter)
sudo reboot
```

**On Worker Pi:**
```bash
ssh pi@192.168.1.101

sudo nano /etc/dhcpcd.conf

# Add:
interface eth0
static ip_address=192.168.1.101/24
static routers=192.168.1.1
static domain_name_servers=192.168.1.1 8.8.8.8

# Save and reboot
sudo reboot
```

**Wait 1-2 minutes for reboot, then verify:**
```bash
ssh pi@192.168.1.100  # Master
ssh pi@192.168.1.101  # Worker
```

### Step 2.3: Update Hosts File (Optional but Recommended)

**On both Raspberry Pis:**
```bash
sudo nano /etc/hosts

# Add:
192.168.1.100  k3s-master
192.168.1.101  k3s-worker-1
```

**On your Windows PC:**
```powershell
# Run as Administrator
notepad C:\Windows\System32\drivers\etc\hosts

# Add:
192.168.1.100  k3s-master
192.168.1.101  k3s-worker-1
```

---

## Phase 3: Cluster Installation

### Step 3.1: Clone Repository on Both Pis

**On Master Pi:**
```bash
ssh pi@k3s-master
cd ~
git clone https://github.com/seadavdic/ClaudeAI.git
cd ClaudeAI/k8s-setup/scripts
ls -l  # Verify scripts are there
```

**On Worker Pi:**
```bash
ssh pi@k3s-worker-1
cd ~
git clone https://github.com/seadavdic/ClaudeAI.git
cd ClaudeAI/k8s-setup/scripts
ls -l
```

### Step 3.2: Run Prerequisites on BOTH Pis

**On Master Pi:**
```bash
ssh pi@k3s-master
cd ~/ClaudeAI/k8s-setup/scripts
sudo bash 00-prerequisites.sh
# Answer 'y' when asked if this is the master node
# Answer 'y' to set hostname
# Answer 'y' to reboot
```

**On Worker Pi:**
```bash
ssh pi@k3s-worker-1
cd ~/ClaudeAI/k8s-setup/scripts
sudo bash 00-prerequisites.sh
# Answer 'n' when asked if this is the master node
# Answer 'y' to set hostname
# Answer 'y' to reboot
```

**⏱️ Wait 2-3 minutes for both to reboot**

### Step 3.3: Install Master Node

```bash
ssh pi@k3s-master
cd ~/ClaudeAI/k8s-setup/scripts
sudo bash 01-install-master.sh

# Script will display:
# - Master IP
# - Node Token
# IMPORTANT: Copy the Node Token - you'll need it for the worker!
```

**Example output:**
```
Master Node IP: 192.168.1.100
Node Token: K107c5...::server:abc123...
```

**Copy the token to a text file on your PC!**

### Step 3.4: Install Worker Node

```bash
ssh pi@k3s-worker-1
cd ~/ClaudeAI/k8s-setup/scripts
sudo bash 02-install-worker.sh

# When prompted:
# Enter Master Node IP address: 192.168.1.100
# Enter Node Token: [paste the token from step 3.3]
```

### Step 3.5: Verify Cluster

**On Master Pi:**
```bash
ssh pi@k3s-master
sudo bash ~/ClaudeAI/k8s-setup/scripts/03-verify-cluster.sh
```

You should see both nodes in "Ready" status!

```
NAME           STATUS   ROLES                  AGE   VERSION
k3s-master     Ready    control-plane,master   5m    v1.28.x+k3s1
k3s-worker-1   Ready    <none>                 2m    v1.28.x+k3s1
```

---

## Phase 4: Access from Your PC

Now set up kubectl on your Windows PC to manage the cluster remotely.

### Step 4.1: Install kubectl on Windows

**Option A: Using winget (Windows 11/10)**
```powershell
winget install Kubernetes.kubectl
```

**Option B: Manual installation**
1. Download kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl-windows/
2. Place kubectl.exe in a folder (e.g., `C:\kubectl\`)
3. Add to PATH environment variable

**Verify installation:**
```powershell
kubectl version --client
```

### Step 4.2: Copy kubeconfig from Master to Your PC

**On Master Pi:**
```bash
ssh pi@k3s-master

# Display the kubeconfig
sudo cat /etc/rancher/k3s/k3s.yaml
```

**On your Windows PC:**

1. Create kubectl config directory:
```powershell
mkdir $env:USERPROFILE\.kube
```

2. Create/edit config file:
```powershell
notepad $env:USERPROFILE\.kube\config
```

3. Copy the entire content from master's `/etc/rancher/k3s/k3s.yaml`

4. **IMPORTANT**: Edit the server line:
```yaml
# Change this line:
    server: https://127.0.0.1:6443

# To your master's IP:
    server: https://192.168.1.100:6443
```

5. Save the file

### Step 4.3: Test Connection from Your PC

```powershell
# Get nodes
kubectl get nodes

# Get all pods
kubectl get pods -A

# Get cluster info
kubectl cluster-info
```

**Expected output:**
```
NAME           STATUS   ROLES                  AGE   VERSION
k3s-master     Ready    control-plane,master   15m   v1.28.x+k3s1
k3s-worker-1   Ready    <none>                 12m   v1.28.x+k3s1
```

### Step 4.4: Deploy Test Application from Your PC

```powershell
# Create nginx deployment
kubectl create deployment nginx --image=nginx --replicas=2

# Expose as NodePort service
kubectl expose deployment nginx --port=80 --type=NodePort

# Get the assigned port
kubectl get svc nginx

# Access nginx in browser:
# http://192.168.1.100:<node-port>
# or
# http://192.168.1.101:<node-port>
```

---

## Quick Reference Commands

### From Your PC (Windows)

```powershell
# View cluster status
kubectl get nodes
kubectl get pods -A
kubectl get svc -A

# Deploy application
kubectl create deployment myapp --image=nginx
kubectl expose deployment myapp --port=80 --type=NodePort

# Scale deployment
kubectl scale deployment myapp --replicas=3

# Delete resources
kubectl delete deployment myapp
kubectl delete svc myapp
```

### SSH to Raspberry Pis

```powershell
ssh pi@k3s-master
ssh pi@k3s-worker-1
```

### On Master Pi (if needed)

```bash
# View cluster from master
kubectl get nodes
kubectl get pods -A

# View k3s logs
sudo journalctl -u k3s -f

# Restart k3s
sudo systemctl restart k3s
```

---

## Troubleshooting

### Cannot connect from PC to cluster

1. **Check network connectivity:**
```powershell
ping k3s-master
```

2. **Verify port 6443 is accessible:**
```powershell
Test-NetConnection -ComputerName k3s-master -Port 6443
```

3. **Check kubeconfig file:**
```powershell
type $env:USERPROFILE\.kube\config
# Verify server IP is correct (not 127.0.0.1)
```

4. **Check master firewall (on master Pi):**
```bash
ssh pi@k3s-master
sudo ufw status  # If enabled, allow port 6443
```

### Worker node not joining

1. **Verify connectivity from worker to master:**
```bash
ssh pi@k3s-worker-1
ping k3s-master
nc -zv k3s-master 6443
```

2. **Check token is correct:**
```bash
# On master
ssh pi@k3s-master
sudo cat /var/lib/rancher/k3s/server/node-token
```

### Kubectl commands slow or timing out

- Check your network connection
- Verify master Pi is running: `ping k3s-master`
- Check k3s service: `ssh pi@k3s-master "sudo systemctl status k3s"`

---

## Summary

✅ **Phase 1**: Flash OS, configure boot settings
✅ **Phase 2**: Set static IPs, configure network
✅ **Phase 3**: Install k3s on master and worker
✅ **Phase 4**: Configure kubectl on your PC

**You can now manage your Kubernetes cluster from your PC!**

---

## Next Steps

- Install [k9s](https://k9scli.io/) for terminal UI cluster management
- Install [Lens](https://k8slens.dev/) for GUI cluster management
- Deploy real applications (databases, web apps, etc.)
- Set up persistent storage
- Configure ingress for external access
- Set up monitoring (Prometheus + Grafana)

Happy clustering! 🚀
