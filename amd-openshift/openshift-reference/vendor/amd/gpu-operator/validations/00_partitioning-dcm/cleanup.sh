#!/bin/bash
#
# Cleanup Script - Reverse All Partitioning Steps
#
# This script cleans up the GPU partitioning configuration by reversing
# all steps from back to front:
#   6. Un-taint node
#   4. Remove partition label
#   2. Disable DCM and remove ConfigMap
#   1. Remove tolerations from control plane (optional)
#



echo "╔════════════════════════════════════════════════════════════════╗"
echo "║       AMD GPU Partitioning Cleanup (Reverse Order)             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Step 6 (Reverse): Un-taint Node
# ──────────────────────────────────────────────────────────────────────────────
kubectl taint nodes "$NODE_NAME" amd-dcm=up:NoExecute-


# ──────────────────────────────────────────────────────────────────────────────
# Step 4 (Reverse): Remove Partition Label
# ──────────────────────────────────────────────────────────────────────────────
kubectl label node "$NODE_NAME" dcm.amd.com/gpu-config-profile-
kubectl label node "$NODE_NAME" dcm.amd.com/gpu-config-profile-state-


# ──────────────────────────────────────────────────────────────────────────────
# Step 2 (Reverse): Disable DCM and Remove ConfigMap
# ──────────────────────────────────────────────────────────────────────────────
kubectl patch deviceconfig amdgpu-driver-install -n "$NAMESPACE" --type='merge' -p '{
    "spec": {
      "configManager": {
        "enable": false
      }
    }
  }'
kubectl wait --for=delete pod \
  -l app.kubernetes.io/name=device-config-manager \
  -n "$NAMESPACE" \
  --timeout=120s
kubectl delete configmap config-manager-config -n "$NAMESPACE"


echo ""
echo "Summary:"
echo "  ✓ Node un-tainted"
echo "  ✓ Partition label removed"
echo "  ✓ DCM disabled"
echo "  ✓ ConfigMap removed"
echo ""
echo "The node is now in a clean state and ready for normal workloads."
echo ""
