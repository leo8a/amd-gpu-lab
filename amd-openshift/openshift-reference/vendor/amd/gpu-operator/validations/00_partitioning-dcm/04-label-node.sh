#!/bin/bash
#
# Step 4: Label Node to Indicate Partitioning Profile
#
# Labels the node with the desired partition profile, which signals DCM
# to apply the GPU partitioning configuration.
#
# The --overwrite flag accounts for any existing gpu-config-profile label.
#

set -euo pipefail

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║       Step 4: Label Node with Partition Profile                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Get the DCM pod on the partitioned node
DCM_POD=$(kubectl get pods -n $NAMESPACE \
  -l app.kubernetes.io/name=device-config-manager \
  --field-selector spec.nodeName=$NODE_NAME \
  -o jsonpath='{.items[0].metadata.name}')

# Labeling node with partition profile...
kubectl label node $NODE_NAME dcm.amd.com/gpu-config-profile=$PROFILE_NAME --overwrite
echo ""

# Wait for DCM to process the profile
echo "Waiting for DCM to process profile (timeout: 5 mins)..."
echo " -> kubectl logs -n $NAMESPACE -c device-config-manager-container $DCM_POD -f"
echo ""

# Wait for DCM to report profile state via node label
echo "Waiting for dcm.amd.com/gpu-config-profile-state label..."
MAX_WAIT=600   # 10 mins
elapsed=0
while [ $elapsed -lt $MAX_WAIT ]; do
  STATE=$(kubectl get node $NODE_NAME -o jsonpath='{.metadata.labels.dcm\.amd\.com/gpu-config-profile-state}' 2>/dev/null || echo "")

  if [ "$STATE" = "success" ]; then
    echo "✓ Profile applied successfully"
    break
  elif [ "$STATE" = "failure" ]; then
    echo "✗ Profile application failed"
    kubectl get node $NODE_NAME -ojson | jq '.metadata.labels | with_entries(select(.key | contains("amd.com")))'
    echo ""
    exit 1
  fi

  sleep 5
  elapsed=$((elapsed + 5))
done

if [ $elapsed -ge $MAX_WAIT ]; then
  echo "✗ Timeout waiting for profile state"
  exit 1
fi

# Previous approach: watch DCM logs for NodeModulesConfig deletion.
# Replaced by label-based approach above which is cleaner.
# for i in {1..150}; do
#   if kubectl logs -n $NAMESPACE -c device-config-manager-container $DCM_POD --tail=50 2>/dev/null | \
#      grep -q "NodeModulesConfig for node $NODE_NAME deleted successfully"; then
#     echo "✓ NodeModulesConfig deleted"
#     break
#   fi
#   sleep 2
# done

echo ""
