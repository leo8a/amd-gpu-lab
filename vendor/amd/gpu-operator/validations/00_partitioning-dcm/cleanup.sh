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



TOLERATION='[{"key": "amd-dcm", "operator": "Equal", "value": "up", "effect": "NoExecute"}]'

CONTROL_PLANE_NAMESPACES=(
  # Networking (CRITICAL - node connectivity)
  "openshift-ovn-kubernetes"
  "openshift-multus"
  "openshift-dns"
  "openshift-dns-operator"
  "openshift-network-operator"
  "openshift-network-diagnostics"
  "openshift-network-node-identity"
  "openshift-network-console"

  # Machine/Node management
  "openshift-machine-config-operator"
  "openshift-machine-api"
  "openshift-cluster-node-tuning-operator"
  "openshift-cluster-machine-approver"

  # API servers and authentication (CRITICAL)
  "openshift-kube-apiserver"
  "openshift-kube-apiserver-operator"
  "openshift-apiserver"
  "openshift-apiserver-operator"
  "openshift-oauth-apiserver"
  "openshift-authentication"
  "openshift-authentication-operator"

  # Controllers (CRITICAL)
  "openshift-kube-controller-manager"
  "openshift-kube-controller-manager-operator"
  "openshift-kube-scheduler"
  "openshift-kube-scheduler-operator"
  "openshift-controller-manager"
  "openshift-controller-manager-operator"
  "openshift-route-controller-manager"

  # Cluster operators (CRITICAL)
  "openshift-cluster-version"
  "openshift-config-operator"
  "openshift-etcd"
  "openshift-etcd-operator"

  # Cloud and cluster services
  "openshift-cloud-controller-manager-operator"
  "openshift-cloud-credential-operator"
  "openshift-cluster-samples-operator"
  "openshift-service-ca"
  "openshift-service-ca-operator"
  "openshift-insights"
)

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
kubectl delete configmap config-manager-config -n "$NAMESPACE"


# ──────────────────────────────────────────────────────────────────────────────
# Step 1 (Reverse): Remove Tolerations (Optional - Interactive)
# ──────────────────────────────────────────────────────────────────────────────
echo ""
read -p "Do you want to remove amd-dcm tolerations? (y/N): " -n 1 -r

if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo ""
  echo "  Removing amd-dcm tolerations from control plane components..."
  echo "  This will preserve other tolerations."
  echo ""

  REMOVED_COUNT=0

  for ns in "${CONTROL_PLANE_NAMESPACES[@]}"; do
    echo ""
    echo "Processing namespace: $ns"

    # Remove from deployments
    for deploy in $(kubectl get deployments -n "$ns" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
      NEW_TOLERATIONS=$(kubectl get deployment "$deploy" -n "$ns" -o json 2>/dev/null | \
        jq '.spec.template.spec.tolerations | map(select(.key != "amd-dcm"))')

      if [ "$NEW_TOLERATIONS" != "null" ]; then
        kubectl patch deployment "$deploy" -n "$ns" --type='json' \
          -p="[{\"op\": \"replace\", \"path\": \"/spec/template/spec/tolerations\", \"value\": $NEW_TOLERATIONS}]" 2>/dev/null || true
        ((REMOVED_COUNT++)) || true
      fi
    done

    # Remove from daemonsets
    for ds in $(kubectl get daemonsets -n "$ns" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
      NEW_TOLERATIONS=$(kubectl get daemonset "$ds" -n "$ns" -o json 2>/dev/null | \
        jq '.spec.template.spec.tolerations | map(select(.key != "amd-dcm"))')

      if [ "$NEW_TOLERATIONS" != "null" ]; then
        kubectl patch daemonset "$ds" -n "$ns" --type='json' \
          -p="[{\"op\": \"replace\", \"path\": \"/spec/template/spec/tolerations\", \"value\": $NEW_TOLERATIONS}]" 2>/dev/null || true
        ((REMOVED_COUNT++)) || true
      fi
    done

    # Remove from statefulsets
    for sts in $(kubectl get statefulsets -n "$ns" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null); do
      NEW_TOLERATIONS=$(kubectl get statefulset "$sts" -n "$ns" -o json 2>/dev/null | \
        jq '.spec.template.spec.tolerations | map(select(.key != "amd-dcm"))')

      if [ "$NEW_TOLERATIONS" != "null" ]; then
        kubectl patch statefulset "$sts" -n "$ns" --type='json' \
          -p="[{\"op\": \"replace\", \"path\": \"/spec/template/spec/tolerations\", \"value\": $NEW_TOLERATIONS}]" 2>/dev/null || true
        ((REMOVED_COUNT++)) || true
      fi
    done
  done
fi

echo ""
echo "Summary:"
echo "  ✓ Node un-tainted"
echo "  ✓ Partition label removed"
echo "  ✓ DCM disabled"
echo "  ✓ ConfigMap removed"
echo "  ✓ Tolerations removed from control plane"
echo ""
echo "The node is now in a clean state and ready for normal workloads."
echo ""
