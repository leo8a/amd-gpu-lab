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
