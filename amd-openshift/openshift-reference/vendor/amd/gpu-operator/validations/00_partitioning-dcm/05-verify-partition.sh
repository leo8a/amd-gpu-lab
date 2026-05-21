#!/bin/bash
#
# Step 5: Verify GPU Partitioning (DCM Partitions the Node)
#
# Uses amd-smi inside the Device Config Manager pod to verify that DCM
# has successfully partitioned the GPUs according to the profile.
#

set -euo pipefail

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║            Step 5: Verify GPU Partitioning                     ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Get the DCM pod on the partitioned node
DCM_POD=$(kubectl get pods -n $NAMESPACE \
  -l app.kubernetes.io/name=device-config-manager \
  --field-selector spec.nodeName=$NODE_NAME \
  -o jsonpath='{.items[0].metadata.name}')

echo "Verifying GPU partitioning with amd-smi..."
echo " -> Node: $NODE_NAME"
echo " -> Config Manager Pod: $DCM_POD"
echo ""

echo "=== AMD version ==="
kubectl exec -n $NAMESPACE -c device-config-manager-container $DCM_POD -- amd-smi version || true
echo ""

echo "=== GPU List ==="
kubectl exec -n $NAMESPACE -c device-config-manager-container $DCM_POD -- amd-smi list || true
echo ""

echo "=== Partition Static Info ==="
kubectl exec -n $NAMESPACE -c device-config-manager-container $DCM_POD -- amd-smi static --partition || true
echo ""

echo "=== GPU List (CSV) ==="
kubectl exec -n $NAMESPACE -c device-config-manager-container $DCM_POD -- amd-smi list --csv || true
echo ""

echo "=== Memory Partition ==="
kubectl exec -n $NAMESPACE -c device-config-manager-container $DCM_POD -- amd-smi partition --memory || true
echo ""

echo "=== Accelerator Partition ==="
kubectl exec -n $NAMESPACE -c device-config-manager-container $DCM_POD -- amd-smi partition --accelerator || true
echo ""


echo ""


# If failed, check the logs:
# -> oc logs -n openshift-amd-gpu -l app.kubernetes.io/name=device-config-manager -f
