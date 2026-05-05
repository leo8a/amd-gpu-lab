#!/bin/bash

set -euo pipefail

NS="openshift-amd-gpu"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 1. Remove /validations resources
oc delete -k "$SCRIPT_DIR"/validations/01_remediation/01_e2e-fault-injection --ignore-not-found
oc delete -k "$SCRIPT_DIR"/validations/01_remediation/00_gpu-validation --ignore-not-found
oc delete -k "$SCRIPT_DIR"/validations/02_dra/01_partitioned-gpu --ignore-not-found
oc delete -k "$SCRIPT_DIR"/validations/02_dra/00_full-gpu --ignore-not-found

# 2. Remove DeviceConfig CR (if any)
oc delete deviceconfig --all -n "$NS" --ignore-not-found

# 3. Wait on CR removal (timeout 3m)
oc wait deviceconfig --all -n "$NS" --for=delete --timeout=3m 2>/dev/null || true

# 4. Remove Subscription, OperatorGroup, Namespace, CatalogSource
oc delete -f "$SCRIPT_DIR"/03_amd-gpu-sub.yaml --ignore-not-found
oc -n "$NS" delete csv -l operators.coreos.com/amd-gpu-operator."$NS"= --ignore-not-found
oc delete -f "$SCRIPT_DIR"/02_amd-gpu-og.yaml --ignore-not-found
oc delete -f "$SCRIPT_DIR"/01_amd-gpu-ns.yaml --ignore-not-found
oc delete -f "$SCRIPT_DIR"/00_amd-gpu-cs.yaml --ignore-not-found

# 5. Remove CRDs
oc delete crd deviceconfigs.amd.com remediationworkflowstatuses.amd.com --ignore-not-found

# 6. Clear stale amd.com/gpu extended resource from nodes
# Kubelet never removes device plugin resources from node status (kubernetes#53395),
# so we must delete its checkpoint (to stop re-advertising) and patch the API (to remove the stale value).
for node in $(oc get nodes -o jsonpath='{.items[?(@.status.capacity.amd\.com/gpu)].metadata.name}'); do
  oc debug node/"$node" -- chroot /host bash -c \
    'rm -f /var/lib/kubelet/device-plugins/kubelet_internal_checkpoint && systemctl restart kubelet'
  oc patch node "$node" --subresource=status --type=json \
    -p '[{"op":"remove","path":"/status/capacity/amd.com~1gpu"},{"op":"remove","path":"/status/allocatable/amd.com~1gpu"}]'
done
