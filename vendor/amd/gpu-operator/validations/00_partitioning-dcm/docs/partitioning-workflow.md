# GPU Partitioning Workflow: Under the Hood

This document explains how GPU partitioning works with node taints and tolerations to safely reconfigure AMD GPUs without disrupting critical components.

## Overview

GPU partitioning requires temporarily preventing workloads from using the GPU while the Device Config Manager (DCM) reconfigures the hardware. We use the `amd-dcm=up:NoExecute` taint to orchestrate which components stay running and which restart to detect the new GPU configuration.

**Key Point**: The AMD GPU Operator configures all necessary tolerations by default - no DeviceConfig changes required!

## Components Involved

### Components That Survive the Taint

These components have the `amd-dcm=up` toleration configured by default:

| Component                       | Purpose                                                   | Default Toleration       |
|---------------------------------|-----------------------------------------------------------|--------------------------|
| **Device Config Manager (DCM)** | Applies GPU partition profiles using AMD tools            | `amd-dcm=up` (NoExecute) |
| **KMM Driver Loader**           | Loads/unloads kernel modules via Kernel Module Management | `amd-dcm=up`             |

### Components That Restart

These components do NOT have the `amd-dcm` toleration and will be evicted/restarted:

| Component            | Purpose                                                | Why It Restarts                                    |
|----------------------|--------------------------------------------------------|----------------------------------------------------|
| **Device Plugin**    | Advertises GPU resources (`amd.com/gpu`) to Kubernetes | Must restart to detect new partition configuration |
| **Node Labeller**    | Maintains GPU-related node labels                      | Restarts to relabel GPUs with new partition info   |
| **Metrics Exporter** | Exports GPU metrics to Prometheus                      | Restarts to export metrics for new partitions      |
| **User Workloads**   | Application pods using GPUs                            | Cannot use GPUs during reconfiguration             |

## The Taint

```bash
kubectl taint nodes <NODE_NAME> amd-dcm=up:NoExecute
```

**Breakdown:**

- **Key**: `amd-dcm`
- **Value**: `up`
- **Effect**: `NoExecute` (evicts pods without matching toleration)

This is the standard AMD GPU partitioning taint as documented in the official AMD GPU Operator documentation.

## Default Toleration Configuration

The AMD GPU Operator automatically configures these tolerations - **no manual DeviceConfig changes needed**:

### DCM DaemonSet

```yaml
tolerations:
  - key: amd-dcm
    operator: Equal
    value: up
    effect: NoExecute
```

### Module (KMM Driver Loader)

```yaml
tolerations:
  - key: amd-dcm
    operator: Equal
    value: up
```

### Operands (No Tolerations)

- Device Plugin: ❌ No `amd-dcm` toleration
- Node Labeller: ❌ No `amd-dcm` toleration
- Metrics Exporter: ❌ No `amd-dcm` toleration

Per AMD documentation: "Avoid adding the amd-dcm toleration to the operands (device plugin, node labeller, metrics exporter, and test runner) daemonsets via the DeviceConfig spec. This ensures operands restart automatically after partitioning completes, allowing them to detect updated GPU resources."

## Step-by-Step Workflow

### 1. Pre-Taint State

```yaml
┌─────────────────────────────────────────────┐
│ GPU Node (No Taints)                        │
├─────────────────────────────────────────────┤
│ ✓ Device Config Manager (DCM)               │
│ ✓ KMM Driver Loader                         │
│ ✓ Node Labeller                             │
│ ✓ Device Plugin                             │
│ ✓ Metrics Exporter                          │
│ ✓ User Workloads                            │
└─────────────────────────────────────────────┘
```

### 2. Apply Taint

```bash
kubectl taint nodes <NODE_NAME> amd-dcm=up:NoExecute
```

**Immediate Effects:**

- Node Labeller: **Evicted** (no toleration)
- Device Plugin: **Evicted** (no toleration)
- Metrics Exporter: **Evicted** (no toleration)
- User Workloads: **Evicted** (no toleration)
- DCM: **Survives** (has toleration)
- Driver Loader: **Survives** (has toleration)

### 3. During Partitioning

```yaml
┌─────────────────────────────────────────────┐
│ GPU Node (Tainted: amd-dcm=up:NoExecute)    │
├─────────────────────────────────────────────┤
│ ✓ Device Config Manager (Running)           │
│ ✓ KMM Driver Loader (Running)               │
│ ✗ Node Labeller (Evicted)                   │
│ ✗ Device Plugin (Evicted)                   │
│ ✗ Metrics Exporter (Evicted)                │
│ ✗ User Workloads (Evicted)                  │
└─────────────────────────────────────────────┘

DCM applies partition profile → GPU reconfigured
```

**Note**: Node labeller being evicted may temporarily remove GPU-related labels. This is expected and labels will be restored when the node labeller restarts after untainting.

### 4. Remove Taint

```bash
kubectl taint nodes <NODE_NAME> amd-dcm-
```

**Immediate Effects:**

- Node Labeller DaemonSet: **Reschedules** new pod → Relabels GPUs
- Device Plugin DaemonSet: **Reschedules** new pod → Detects new partitions
- Metrics Exporter DaemonSet: **Reschedules** new pod
- User workloads can schedule again

### 5. Post-Taint State

```yaml
┌─────────────────────────────────────────────┐
│ GPU Node (No Taints)                        │
├─────────────────────────────────────────────┤
│ ✓ Device Config Manager (DCM)               │
│ ✓ KMM Driver Loader                         │
│ ✓ Node Labeller (NEW POD - relabels GPUs)   │
│ ✓ Device Plugin (NEW POD - detects partitions)│
│ ✓ Metrics Exporter (NEW POD)                │
│ ✓ User Workloads (can schedule)             │
└─────────────────────────────────────────────┘
```

## Verification Commands

### Check Tolerations (Before Tainting)

```bash
# DCM should have amd-dcm toleration
oc get daemonset amdgpu-driver-install-device-config-manager -n openshift-amd-gpu \
  -o jsonpath='{.spec.template.spec.tolerations}' | jq '.[] | select(.key=="amd-dcm")'

# Module (driver) should have amd-dcm toleration
oc get module -n openshift-amd-gpu amdgpu-driver-install \
  -o jsonpath='{.spec.tolerations}' | jq '.[] | select(.key=="amd-dcm")'

# Device plugin should NOT have amd-dcm toleration (should return empty)
oc get daemonset amdgpu-driver-install-device-plugin -n openshift-amd-gpu \
  -o jsonpath='{.spec.template.spec.tolerations}' | jq '.[] | select(.key=="amd-dcm")'

# Node labeller should NOT have amd-dcm toleration (should return empty)
oc get daemonset amdgpu-driver-install-node-labeller -n openshift-amd-gpu \
  -o jsonpath='{.spec.template.spec.tolerations}' | jq '.[] | select(.key=="amd-dcm")'
```

### Check During Taint

```bash
# Verify taint is applied
oc get node <NODE_NAME> -o jsonpath='{.spec.taints}' | jq '.[] | select(.key=="amd-dcm")'

# DCM and driver loader should still be running
oc get pods -n openshift-amd-gpu -l app.kubernetes.io/name=device-config-manager

# Device plugin, node labeller, metrics should be gone
oc get pods -n openshift-amd-gpu
```

### Check After Untaint

```bash
# Verify taint is removed
oc get node <NODE_NAME> -o jsonpath='{.spec.taints}'

# All DaemonSets should be running with new pods
oc get pods -n openshift-amd-gpu -o wide

# Verify new GPU resources are detected
oc get node <NODE_NAME> -o jsonpath='{.status.allocatable}' | jq '."amd.com/gpu"'
```

## Troubleshooting

### DCM Pod Missing During Taint

**Symptom**: DCM pod gets evicted when taint is applied

**Cause**: DCM DaemonSet missing default `amd-dcm` toleration

**Check**:

```bash
oc get daemonset amdgpu-driver-install-device-config-manager -n openshift-amd-gpu \
  -o jsonpath='{.spec.template.spec.tolerations}' | jq .
```

**Expected**: Should see `amd-dcm=up` toleration

**Resolution**: This should be configured by default. If missing, verify AMD GPU Operator version and reinstall if necessary.

### Device Plugin Doesn't Detect New Partitions

**Symptom**: After untainting, device plugin still shows old GPU count

**Cause**: Device plugin pod didn't restart (has amd-dcm toleration when it shouldn't)

**Check**:

```bash
oc get daemonset amdgpu-driver-install-device-plugin -n openshift-amd-gpu \
  -o jsonpath='{.spec.template.spec.tolerations}' | jq '.[] | select(.key=="amd-dcm")'
```

**Expected**: Should return empty (no amd-dcm toleration)

**Resolution**: Remove any `devicePluginTolerations` from DeviceConfig if configured

### Node Labels Missing After Partitioning

**Symptom**: GPU-related node labels not updated after partitioning

**Cause**: Node labeller pod didn't restart properly

**Check**:

```bash
oc get pods -n openshift-amd-gpu -l app=amd-gpu -l openshift.io/component=amdgpu-node-labeller
```

**Resolution**: Node labeller should restart automatically when taint is removed. If stuck, manually delete the pod to force recreation.

## Why This Pattern Works

From AMD's documentation:

> Avoid adding the amd-dcm toleration to the operands (device plugin, node labeller, metrics exporter, and test runner) daemonsets via the DeviceConfig spec.
>
> This ensures operands restart automatically after partitioning completes, allowing them to detect updated GPU resources.

The AMD GPU Operator implements this pattern by default:

- **DCM and driver loader**: Have `amd-dcm` toleration → survive taint → perform partitioning
- **Operands (device plugin, node labeller, metrics)**: No toleration → evicted → restart after untaint → detect new config
- **No manual configuration needed**: Everything works out of the box

## Reference

This workflow follows AMD's official GPU partitioning documentation:

- [Applying Partition Profiles](https://instinct.docs.amd.com/projects/gpu-operator/en/latest/dcm/applying-partition-profiles.html)
- [AMD GPU Operator Installation](https://instinct.docs.amd.com/projects/gpu-operator/en/latest/installation/openshift-olm.html)
