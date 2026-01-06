#!/bin/bash

###############################################################################
# Kubernetes Cluster Setup - Cluster Verification
# Script to verify the health and status of the k3s cluster
# Run this on the MASTER node after all nodes have joined
###############################################################################

set -e

echo "======================================"
echo "K3s Cluster Verification"
echo "======================================"
echo ""

# Check if running on master
if ! systemctl is-active --quiet k3s; then
    echo "ERROR: This script should run on the master node"
    echo "k3s service is not running on this node"
    exit 1
fi

# Node Status
echo "[1/5] Checking Node Status..."
echo "======================================"
kubectl get nodes -o wide
echo ""

# Count nodes
TOTAL_NODES=$(kubectl get nodes --no-headers | wc -l)
READY_NODES=$(kubectl get nodes --no-headers | grep -c "Ready" || true)

echo "Total Nodes: $TOTAL_NODES"
echo "Ready Nodes: $READY_NODES"
echo ""

if [ "$READY_NODES" -lt "$TOTAL_NODES" ]; then
    echo "WARNING: Not all nodes are Ready!"
    echo ""
fi

# System Pods
echo "[2/5] Checking System Pods..."
echo "======================================"
kubectl get pods -A
echo ""

# Check if all pods are running
NOT_RUNNING=$(kubectl get pods -A --no-headers | grep -v "Running\|Completed" | wc -l || true)
if [ "$NOT_RUNNING" -gt 0 ]; then
    echo "WARNING: $NOT_RUNNING pod(s) are not running!"
    echo "Problematic pods:"
    kubectl get pods -A | grep -v "Running\|Completed\|STATUS" || true
    echo ""
fi

# Services
echo "[3/5] Checking Services..."
echo "======================================"
kubectl get svc -A
echo ""

# Cluster Info
echo "[4/5] Cluster Information..."
echo "======================================"
kubectl cluster-info
echo ""
kubectl version --short 2>/dev/null || kubectl version
echo ""

# Resource Usage
echo "[5/5] Node Resource Usage..."
echo "======================================"
for node in $(kubectl get nodes -o jsonpath='{.items[*].metadata.name}'); do
    echo "Node: $node"
    kubectl describe node "$node" | grep -A 5 "Allocated resources:" || true
    echo ""
done

# Summary
echo "======================================"
echo "Verification Summary"
echo "======================================"
if [ "$READY_NODES" -eq "$TOTAL_NODES" ] && [ "$NOT_RUNNING" -eq 0 ]; then
    echo "✓ Cluster is healthy!"
    echo "✓ All nodes are Ready"
    echo "✓ All pods are Running"
else
    echo "⚠ Cluster has issues:"
    [ "$READY_NODES" -lt "$TOTAL_NODES" ] && echo "  - Not all nodes are Ready"
    [ "$NOT_RUNNING" -gt 0 ] && echo "  - Some pods are not Running"
fi
echo ""
echo "Cluster ready for workloads!"
echo "======================================"
