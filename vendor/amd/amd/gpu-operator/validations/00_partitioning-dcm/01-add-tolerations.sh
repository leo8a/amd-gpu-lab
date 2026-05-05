#!/bin/bash
#
# Step 1: Add Tolerations to Control Plane Components
#
# Add tolerations to all Deployments and DaemonSets in critical control plane namespaces.
# This allows control plane pods to tolerate and survive an "amd-dcm=up:NoExecute" taint
# applied to the node when enabling GPU partitioning.
#
# This step prevents accidental eviction of essential control plane workloads from GPU nodes.
#
# IMPORTANT NOTE: This list of OpenShift namespaces for cluster operators and critical
# components may change from release to release. Always verify against your cluster.
#

set -euo pipefail

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         Step 1: Add Tolerations to Control Plane               ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
read -p "Do you want to add amd-dcm tolerations? (y/N): " -n 1 -r

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Operation cancelled."
  echo ""
  exit 0
fi

# Configuration (can be overridden via environment variables)
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

echo ""
echo "Adding tolerations to control plane components..."
echo "This ensures critical components survive node tainting during GPU partitioning"
echo ""

for ns in "${CONTROL_PLANE_NAMESPACES[@]}"; do
  echo ""
  echo "Patching namespace: $ns"

  # Patch deployments
  kubectl get deployments -n "$ns" -o json 2>/dev/null | \
    jq -r '.items[] | .metadata.name' | \
    xargs -I {} kubectl patch deployment {} -n "$ns" --type='json' \
    -p='[{"op": "add", "path": "/spec/template/spec/tolerations", "value": '"$TOLERATION"'}]' 2>/dev/null || true

  # Patch daemonsets
  kubectl get daemonsets -n "$ns" -o json 2>/dev/null | \
    jq -r '.items[] | .metadata.name' | \
    xargs -I {} kubectl patch daemonset {} -n "$ns" --type='json' \
    -p='[{"op": "add", "path": "/spec/template/spec/tolerations", "value": '"$TOLERATION"'}]' 2>/dev/null || true

  # Patch statefulsets
  kubectl get statefulsets -n "$ns" -o json 2>/dev/null | \
    jq -r '.items[] | .metadata.name' | \
    xargs -I {} kubectl patch statefulset {} -n "$ns" --type='json' \
    -p='[{"op": "add", "path": "/spec/template/spec/tolerations", "value": '"$TOLERATION"'}]' 2>/dev/null || true
done

echo ""
echo "✓ Tolerations added to all control plane components"
echo ""


# Verification:
# -> oc get pod -n openshift-kmm -ojson | jq .items[].spec.tolerations
