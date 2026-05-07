# Troubleshooting Guide

---

## Memory Partitioning Not Working on MI300X (DELL PowerEdge XE9680)

### Symptoms

Memory partitioning options (NPS1, NPS4) are the only ones available, missing NPS2 (which is supported). Additionally CPX partitioning works but no memory partitioning i.e., NPS4 can be completed via the DCM procedure.

Available Memory Partitions

```shell
cat /sys/module/amdgpu/drivers/pci\:amdgpu/*/available_memory_partition
NPS1, NPS4
NPS1, NPS4
NPS1, NPS4
NPS1, NPS4
NPS1, NPS4
NPS1, NPS4
NPS1, NPS4
NPS1, NPS4
```

VBIOS version:

```bash
kubectl exec -n $NAMESPACE $DCM_POD -- amd-smi static | grep -A 4 -m 1 'VBIOS'

    VBIOS:
        NAME: AMD MI300X_HW_SRIOV_CVS_1VF
        BUILD_DATE: 2024/08/06 18:01
        PART_NUMBER: 113-M3000100-102
        VERSION: 022.040.003.041.000001
```

### Root Cause

VBIOS firmware version is outdated:

- Current: `022.040.003.041.000001`
- Required: `022.040.003.043.000001`

### Solution

Update VBIOS firmware to version `022.040.003.043.000001` or newer.

- [Dell System Drivers Page](https://www.dell.com/support/product-details/en-us/servicetag/0-R0tISFZtTmtJYmM4eXB3QUdwWGlxUT090/drivers)

Once updated, perform a Full Full Power Cycle via the iDRAC. After that the available memory partitions changed.

```bash
[root@j42-h01-000-xe9680 ~]# cat /sys/module/amdgpu/drivers/pci\:amdgpu/*/{available_compute_partition,available_memory_partition}
SPX, DPX, QPX, CPX
SPX, DPX, QPX, CPX
SPX, DPX, QPX, CPX
SPX, DPX, QPX, CPX
SPX, DPX, QPX, CPX
SPX, DPX, QPX, CPX
SPX, DPX, QPX, CPX
SPX, DPX, QPX, CPX
NPS1, NPS2, NPS4
NPS1, NPS2, NPS4
NPS1, NPS2, NPS4
NPS1, NPS2, NPS4
NPS1, NPS2, NPS4
NPS1, NPS2, NPS4
NPS1, NPS2, NPS4
NPS1, NPS2, NPS4
```

Applied VBIOS update.

```bash
[leo8a@red-fedora gpu-partitioning]$ kubectl exec -n $NAMESPACE $DCM_POD -- amd-smi static | grep -A 4 -m 1 'VBIOS'
Defaulted container "device-config-manager-container" out of: device-config-manager-container, driver-init (init)
    VBIOS:
        NAME: AMD MI300X_HW_SRIOV_CVS_1VF
        BUILD_DATE: 2025/07/27 14:45
        PART_NUMBER: 113-M3000108-103
        VERSION: 022.040.003.043.000001
```

### Reference

[AMD MI300X Requirements](https://instinct.docs.amd.com/projects/amdgpu-docs/en/latest/gpu-partitioning/mi300x/requirements.html)

---

## DCM Fails with "Failed to initialize AMD SMI" Error

### Symptoms

DCM partitioning fails with AMD SMI initialization errors:

```bash
kubectl logs -n openshift-amd-gpu -l app.kubernetes.io/name=device-config-manager

2026/02/26 09:55:20 Partitioning the GPU
2026/02/26 09:55:20 Selected Profile cpx-profile-nps4 found in the configmap.
Exception caught: rsmi_init.
time="2026-02-26T09:55:20Z" level=error msg="Failed to initialize AMD SMI!"
time="2026-02-26T09:55:20Z" level=error msg="Failed to get compute partition 2"
time="2026-02-26T09:55:20Z" level=error msg="Failed to compute partition Command not supported."
```

Node shows `dcm.amd.com/gpu-config-profile-state: failure`.

### Root Cause

Incorrectly adding the `amd-dcm` toleration to the entire `openshift-amd-gpu` namespace prevents GPU operator operands from restarting after partitioning.

**Per AMD best practices:**

- **DCM pod**: Gets toleration automatically via DeviceConfig spec
- **Operands** (device-plugin, node-labeller, metrics-exporter): Must NOT have tolerations
  - They need to be evicted during partitioning and restart afterward to detect new GPU resources

Reference: [AMD DCM - Applying Partition Profiles](https://instinct.docs.amd.com/projects/gpu-operator/en/latest/dcm/applying-partition-profiles.html)

### Solution

Remove `"openshift-amd-gpu"` from the toleration namespace list in `01-add-tolerations.sh` (line 51).

The DCM pod gets its toleration automatically, and operands must restart to detect the partitioned GPUs.

---

## DCM Pod Not Scheduling After Node Taint (Chicken-and-Egg Bug)

### Symptoms

After tainting a node with `amd-dcm=up:NoExecute`, the DCM pod disappears from the target node. The DaemonSet shows `desired: 1` instead of `2`, and partitioning cannot proceed because DCM is not running on the node.

```bash
kubectl get pods -n openshift-amd-gpu -l app.kubernetes.io/name=device-config-manager -o wide
# Only shows pod on the OTHER node, not the one being partitioned
```

### Root Cause

The DCM DaemonSet has a `nodeSelector` that requires the KMM driver-ready label:

```yaml
kmm.node.kubernetes.io/openshift-amd-gpu.amdgpu-driver-install.ready: ""
```

When the node is tainted, the KMM driver pod is evicted, and KMM removes the `.ready` label from the node. The DCM DaemonSet then considers the node ineligible for scheduling, even though the DCM pod itself has the `amd-dcm` toleration.

This is set in the operator source at `internal/configmanager/configmanager.go`:

```go
if utils.ShouldUseKMM(devConfig) {
    nodeSelector[labels.GetKernelModuleReadyNodeLabel(...)] = ""
}
```

The `feature.node.kubernetes.io/amd-gpu` label (set by node-labeller) may also be removed after eviction.

### Workaround

Manually re-add the required labels before or immediately after tainting:

```bash
kubectl label node <NODE_NAME> \
  "feature.node.kubernetes.io/amd-gpu=true" \
  "kmm.node.kubernetes.io/openshift-amd-gpu.amdgpu-driver-install.ready=" \
  --overwrite
```

### Upstream Fix

The DCM DaemonSet should not gate on the KMM driver-ready label, since DCM needs to run on the node precisely when the driver is being reconfigured. The `amd-dcm` toleration is correctly set but the `nodeSelector` defeats its purpose.
