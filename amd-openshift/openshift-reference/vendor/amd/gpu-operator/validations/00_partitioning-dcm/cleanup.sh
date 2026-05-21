#!/bin/bash
#
# Cleanup Script - Reverse All Partitioning Steps
#
# This script cleans up the GPU partitioning configuration by reversing
# all steps from back to front:
#   Un-taint node
#   Disable DCM and remove ConfigMap
#



echo "╔════════════════════════════════════════════════════════════════╗"
echo "║       AMD GPU Partitioning Cleanup (Reverse Order)             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# Un-taint Node
# ──────────────────────────────────────────────────────────────────────────────
kubectl taint nodes "$NODE_NAME" amd-dcm=up:NoExecute-


# ──────────────────────────────────────────────────────────────────────────────
# Disable DCM and Remove ConfigMap
# ──────────────────────────────────────────────────────────────────────────────
kubectl patch deviceconfig amdgpu-driver-install -n "$NAMESPACE" --type='merge' -p '{
    "spec": {
      "configManager": {
        "enable": false
      }
    }
  }'
kubectl delete configmap config-manager-config -n "$NAMESPACE"


echo ""
echo "Summary:"
echo "  ✓ Node un-tainted"
echo "  ✓ DCM disabled"
echo "  ✓ ConfigMap removed"
echo ""
echo "The node is now in a clean state and ready for normal workloads."
echo ""
