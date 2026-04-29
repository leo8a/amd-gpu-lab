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

# Labeling node with partition profile...
echo ""
kubectl label node $NODE_NAME dcm.amd.com/gpu-config-profile=$PROFILE_NAME --overwrite

# Wait for DCM to process the profile
echo "Waiting for DCM to process profile (DCM timeout is 5 mins + retries to match expected memory partition value)..."
echo " -> kubectl logs -n openshift-amd-gpu -l app.kubernetes.io/name=device-config-manager -f"

# Wait for DCM to confirm NodeModulesConfig deletion
echo "Waiting for NodeModulesConfig deletion..."
for i in {1..150}; do
  if kubectl logs -n $NAMESPACE -l app.kubernetes.io/name=device-config-manager --tail=50 2>/dev/null | \
     grep -q "NodeModulesConfig for node $NODE_NAME deleted successfully"; then
    echo "✓ NodeModulesConfig deleted"
    break
  fi
  sleep 2
done

# This approach is way more clean BUT once DCM finished processing the profile, 
# it needs that KMM run the driver install process again so it can detect the 
# new compute / memory partition. Which is why we CANNOT simply wait for the label here.
# MAX_WAIT=600   # 10 mins
# elapsed=0
# while [ $elapsed -lt $MAX_WAIT ]; do
#   STATE=$(kubectl get node $NODE_NAME -o jsonpath='{.metadata.labels.dcm\.amd\.com/gpu-config-profile-state}' 2>/dev/null || echo "")

#   if [ "$STATE" = "success" ]; then
#     echo "Profile applied successfully"
#     break
#   elif [ "$STATE" = "failure" ]; then
#     echo "Profile application failed"
#     kubectl get node $NODE_NAME -ojson | jq '.metadata.labels | with_entries(select(.key | contains("amd.com")))'
#     echo ""
#     exit 1
#   fi

#   sleep 5
#   elapsed=$((elapsed + 5))
# done

# if [ $elapsed -ge $MAX_WAIT ]; then
#   echo "Timeout waiting for profile state"
#   exit 1
# fi

echo ""
