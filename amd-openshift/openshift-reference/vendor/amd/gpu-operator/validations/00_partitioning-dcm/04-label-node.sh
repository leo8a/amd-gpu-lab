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

# Stream DCM logs and wait for completion marker or timeout (5 mins)
echo "Waiting for DCM to process profile (timeout: 5 mins)..."
echo " -> kubectl logs -n $NAMESPACE -c device-config-manager-container $DCM_POD -f"
echo ""

LOG_FIFO=$(mktemp -u)
mkfifo "$LOG_FIFO"
trap 'rm -f "$LOG_FIFO"' EXIT

kubectl logs -n $NAMESPACE -c device-config-manager-container $DCM_POD -f 2>/dev/null > "$LOG_FIFO" &
LOG_PID=$!
cleanup_log() { kill $LOG_PID 2>/dev/null; wait $LOG_PID 2>/dev/null || true; rm -f "$LOG_FIFO"; }
trap cleanup_log EXIT

if timeout 300 sed '/PreStateDB has been successfully emptied./q' "$LOG_FIFO"; then
  cleanup_log; trap - EXIT
  echo ""
  echo "✓ Profile applied successfully"
else
  cleanup_log; trap - EXIT
  echo ""
  echo "✗ Timeout waiting for DCM to finish processing"
  exit 1
fi

echo ""
