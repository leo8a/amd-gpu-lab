#!/bin/bash
#
# Step 3: Taint Node to Evict All Workloads
#
# Taints the node with amd-dcm=up:NoExecute to immediately evict all non-essential
# workloads and prevent scheduling of new workloads on the node.
#
# This ensures there are no workloads using the GPUs before partitioning.
# Only pods and DaemonSets with the matching toleration will remain running.
#

set -euo pipefail

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         Step 3: Taint Node to Evict Workloads                  ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Tainting node to evict workloads...
kubectl taint nodes "$NODE_NAME" amd-dcm=up:NoExecute

# Wait for pods to be evicted
echo "Waiting 30s for non-essential pods to terminate..."
sleep 30

# Workaround: scale down devmetrics prometheus if it exists, so it doesn't block GPU partitioning
if kubectl get namespace devmetrics &>/dev/null; then
  kubectl patch prometheus amd-gpu-prometheus -n devmetrics --type='merge' -p '{"spec":{"replicas":0}}' || true
  oc delete pod -n devmetrics prometheus-amd-gpu-prometheus-0 --force --grace-period=0 || true
fi


echo ""
