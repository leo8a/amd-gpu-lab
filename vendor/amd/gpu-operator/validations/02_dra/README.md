# DRA (Dynamic Resource Allocation) Validation

Validates that DRA-based GPU allocation works end-to-end with the AMD GPU Operator 1.5.0+.

Two test scenarios are covered, each in its own subfolder:

| Test                               | What it validates                                                          |
| ---------------------------------- | -------------------------------------------------------------------------- |
| `00_full-gpu/`                     | A single GPU is allocated via `ResourceClaimTemplate` + `DeviceClass`      |
| `01_partitioned-gpu/`              | A GPU partition (e.g. CPX) is allocated via CEL selector on the DRA driver |

> **Note:** GPU virtualization (vGPU / Virt) is **not supported** with AMD DRA at this time.

## Prerequisites

- AMD GPU Operator >= 1.5.0 deployed
- OpenShift 4.18+ / Kubernetes 1.32+ with `DynamicResourceAllocation` feature gate enabled
- CDI (Container Device Interface) enabled in the container runtime
- AMD GPU driver (amdgpu kernel module) loaded on worker nodes
- For the partitioned GPU test: GPU partitioning configured via Device Config Manager

## Quick start

```bash
# Step 1: Enable DRA on the DeviceConfig (disables the legacy Device Plugin)
oc patch deviceconfig amdgpu-driver-install -n openshift-amd-gpu --type merge \
  --patch-file 00_deviceconfig-dra-patch.yaml

# Step 2: Restart kubelet on GPU worker nodes to clear stale device plugin resources
#
# IMPORTANT: When switching from Device Plugin to DRA, the kubelet caches the old
# extended resources (e.g. amd.com/gpu: 8) in node capacity/allocatable. These stale
# entries persist until the kubelet is restarted. Without this step, both the old
# device plugin resources and the new DRA ResourceSlices appear simultaneously,
# which can cause scheduling confusion.
for node in $(oc get nodes -l feature.node.kubernetes.io/amd-gpu=true -o name); do
  echo "Restarting kubelet on ${node}..."
  oc debug "${node}" -- chroot /host systemctl restart kubelet
done

# Step 3: Wait for the DRA driver DaemonSet to be ready
oc -n openshift-amd-gpu get daemonset -l app=dra-driver -w

# Step 4: Run a specific test
oc apply -k 00_full-gpu/         # full GPU test
oc apply -k 01_partitioned-gpu/  # partitioned GPU test
```

See each subfolder's README for detailed verify and cleanup instructions.

## Cleanup

```bash
# Delete test resources
oc delete -k 00_full-gpu/
oc delete -k 01_partitioned-gpu/

# Restore the base DeviceConfig (Device Plugin enabled, DRA disabled)
oc apply -f ../../07_amd-deviceconfig.yaml
```
