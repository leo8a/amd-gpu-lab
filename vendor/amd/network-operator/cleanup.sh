#!/bin/bash

set -euo pipefail

NS="openshift-amd-network"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 1. Remove /validations resources
oc delete -k "$SCRIPT_DIR"/validations/00_cluster-validation --ignore-not-found
oc delete -k "$SCRIPT_DIR"/validations/01_basic/00_nic-assignment --ignore-not-found
oc delete -k "$SCRIPT_DIR"/validations/02_rdma/01_multi-node --ignore-not-found
oc delete -k "$SCRIPT_DIR"/validations/02_rdma/00_single-pod --ignore-not-found
oc delete -k "$SCRIPT_DIR"/validations/03_sriov/01_hnic_pf1_vf8-profile --ignore-not-found
oc delete -k "$SCRIPT_DIR"/validations/03_sriov/00_pf1_vf1-profile --ignore-not-found

# 2. Remove NetworkConfig CR (if any)
oc delete networkconfig --all -n "$NS" --ignore-not-found

# 3. Wait on CR removal (timeout 3m)
oc wait networkconfig --all -n "$NS" --for=delete --timeout=3m 2>/dev/null || true

# 4. Remove Subscription, OperatorGroup, Namespace, CatalogSource
oc delete -f "$SCRIPT_DIR"/03_amd-network-sub.yaml --ignore-not-found
oc -n "$NS" delete csv -l operators.coreos.com/amd-network-operator."$NS"= --ignore-not-found
oc delete -f "$SCRIPT_DIR"/02_amd-network-og.yaml --ignore-not-found
oc delete -f "$SCRIPT_DIR"/01_amd-network-ns.yaml --ignore-not-found
oc delete -f "$SCRIPT_DIR"/00_amd-network-cs.yaml --ignore-not-found

# 5. Remove CRDs
oc delete crd networkconfigs.amd.com --ignore-not-found

# 6. Clear stale amd.com/nic and amd.com/vnic extended resources from nodes
# Kubelet never removes device plugin resources from node status (kubernetes#53395),
# so we must delete its checkpoint (to stop re-advertising) and patch the API (to remove the stale value).
for node in $(oc get nodes -o jsonpath='{.items[?(@.status.capacity.amd\.com/nic)].metadata.name}'); do
  oc debug node/"$node" -- chroot /host bash -c \
    'rm -f /var/lib/kubelet/device-plugins/kubelet_internal_checkpoint && systemctl restart kubelet'
  oc patch node "$node" --subresource=status --type=json \
    -p '[{"op":"remove","path":"/status/capacity/amd.com~1nic"},{"op":"remove","path":"/status/allocatable/amd.com~1nic"}]'
  oc patch node "$node" --subresource=status --type=json \
    -p '[{"op":"remove","path":"/status/capacity/amd.com~1vnic"},{"op":"remove","path":"/status/allocatable/amd.com~1vnic"}]'
done
