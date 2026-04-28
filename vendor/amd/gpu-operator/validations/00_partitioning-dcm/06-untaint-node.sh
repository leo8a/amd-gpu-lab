#!/bin/bash
#
# Step 6: Un-taint Node to Allow Workload Scheduling
#
# Removes the taint from the node to add it back to the cluster so workloads
# can be scheduled again.
#
# Reference commands to revert:
#   Revert to SPX:
#     kubectl label node $NODE_NAME dcm.amd.com/gpu-config-profile=spx-profile --overwrite
#   Remove partition profile:
#     kubectl label node $NODE_NAME dcm.amd.com/gpu-config-profile-
#

set -euo pipefail

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║        Step 6: Un-taint Node for Scheduling                    ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Removing taint from node...
echo "Node: $NODE_NAME"
echo ""

kubectl taint nodes $NODE_NAME amd-dcm=up:NoExecute- || true


echo ""
echo "✓ Taint removed - node ready for workload scheduling"
echo "✓ GPU partitioning workflow complete"


# Workaround
kubectl patch prometheus amd-gpu-prometheus -n devmetrics --type='merge' -p '{"spec":{"replicas":1}}'


echo ""
