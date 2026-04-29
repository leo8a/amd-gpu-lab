# Issues and Enhancements identified

---

## Partitioning Persistence after Reboots

Should be solved in: [[Feature]: Orchestration of cluster partitioning workflow](https://github.com/ROCm/gpu-operator/issues/362).

### Symptoms

After successfully partitioning GPUs to CPX + NPS4 and rebooting the node, the GPU configuration automatically reverts to SPX + NPS1 (default), even though the node retains the profile label `dcm.amd.com/gpu-config-profile=cpx-profile-nps4`.

Node labels after reboot:

```bash
dcm.amd.com/gpu-config-profile=cpx-profile-nps4
dcm.amd.com/gpu-config-profile-state=failure
```

### Root Cause

**GPU partitioning is NOT persistent across reboots** because:

1. **No kernel boot parameters for partitioning**: AMD MI300X GPUs do not support kernel parameters (like `amdgpu.compute_partition=CPX` or `amdgpu.memory_partition=NPS4`) to set partitioning at boot time. The GPU always boots in default configuration: **SPX + NPS1**.

2. **DCM attempts runtime partitioning but fails**: After reboot, the Device Config Manager (DCM) detects the `cpx-profile-nps4` label and attempts to apply the partition configuration. However, this fails because:
   - The node is **NOT tainted** after reboot
   - All workload pods (100+) are running and using GPU resources
   - The `amdgpu` driver is **busy and in use** - cannot be unloaded/reloaded
   - DCM partition operation requires exclusive GPU access

What Happened After Reboot:

  1. Node boots with default GPU configuration: SPX + NPS1 (no kernel parameters set)
  2. Node still has the profile label: `dcm.amd.com/gpu-config-profile=cpx-profile-nps4`
  3. DCM tries to apply CPX + NPS4 immediately after boot
  4. BUT the node is NOT tainted - all workload pods are running
  5. amdgpu driver is IN USE - DCM cannot reload it
  6. Partitioning fails → GPU stays in SPX + NPS1
  7. Profile state set to: `dcm.amd.com/gpu-config-profile-state=failure`

### Evidence from Logs

**dmesg output** shows repeated NPS mode change requests failing:

```logs
[ 968.147632] amdgpu 0000:05:00.0: amdgpu: NPS mode change requested, please remove and reload the driver
[ 968.200342] amdgpu 0000:15:00.0: amdgpu: NPS mode change requested, please remove and reload the driver
[ 968.246881] amdgpu 0000:65:00.0: amdgpu: NPS mode change requested, please remove and reload the driver
...
```

**DCM logs** confirm the failure reason:

```logs
time="2026-02-27T13:42:23Z" level=error msg="Failed to reload driver Device busy."
time="2026-02-27T13:42:23Z" level=error msg="Failed to memory partition Call succeeded."
2026/02/27 13:42:23 Error recover memory partition by running 'modprobe -rv amdgpu': exit status 1,
  output: modprobe: FATAL: Module amdgpu is in use.
2026/02/27 13:42:23 Memory partition handling failed, cannot recover memory partition.
```

```logs
time="2026-02-27T13:41:02Z" level=error msg="There might be existing pods/daemonsets on the cluster
  keeping the GPU resource busy, please remove them and retry. Pods list on this node:
  [grafana-..., prometheus-..., amdgpu-driver-install-device-plugin-..., ...]"
```

### Why This Happens

The GPU partitioning workflow **requires exclusive GPU access** to:

1. Unload the `amdgpu` driver
2. Apply hardware partition configuration via AMD SMI
3. Reload the `amdgpu` driver with new partition topology

This is only possible when:

- The node is **tainted** to prevent pod scheduling
- All GPU workloads are **evicted** (driver not in use)
- DCM has exclusive access to GPU hardware

After a reboot, OpenShift/Kubernetes automatically:

- Removes all taints (returns to schedulable state)
- Schedules all pods back to the node
- Starts GPU device plugin and other GPU-consuming services

By the time DCM starts and attempts partitioning, the driver is already in use and locked.

**Manual re-partitioning required after every reboot:**

```bash
# Step 1: Taint the node to evict workloads
make taint

# Step 2: Verify pods evacuated and GPU driver is idle
oc get pods -A --field-selector spec.nodeName=$NODE_NAME

# Step 3: DCM will automatically detect the label and apply partitioning
# Monitor DCM logs:
oc logs -n openshift-amd-gpu -l app.kubernetes.io/name=device-config-manager -f

# Step 4: Verify partitioning succeeded
oc debug node/$NODE_NAME -- chroot /host cat /sys/module/amdgpu/drivers/pci:amdgpu/0000:05:00.0/current_compute_partition
# Expected: CPX

# Step 5: Un-taint the node
make untaint
```

### Questions for AMD

1. **Is there a way to set GPU partitioning at boot time?**
   - Are there any BIOS/UEFI settings to pre-configure compute/memory partitioning?
   - Can partitioning be set via kernel parameters or modprobe options?

2. **Can partitioning be made persistent in firmware/hardware?**
   - Is there a way to store the partition configuration in GPU VBIOS/firmware that survives reboots?
   - Would a "sticky" partition mode be feasible?

3. **Is there a boot-time partitioning mechanism?**
   - Could DCM be enhanced to run earlier in the boot process (e.g., via systemd oneshot service) before any GPU consumers start?
   - Would a pre-driver-load hook be possible to set partitioning before `amdgpu` module loads?

4. **Best practice for production environments?**
   - What is AMD's recommended approach for maintaining GPU partitioning in production clusters where node reboots are necessary for maintenance?
   - Should we consider partitioning as ephemeral and design workloads accordingly?

### Technical Details

**Current kernel parameters** (verified via `/proc/cmdline`):

```bash
oc debug node/$NODE_NAME -- chroot /host cat /proc/cmdline
# Missing any amdgpu partition-related parameters
```

**Partition detection at boot:**

```bash
# GPU boots in default mode
cat /sys/module/amdgpu/drivers/pci:amdgpu/0000:05:00.0/current_compute_partition
SPX

cat /sys/module/amdgpu/drivers/pci:amdgpu/0000:05:00.0/current_memory_partition
NPS1
```

**Available partitions** (capabilities unchanged):

```bash
cat /sys/module/amdgpu/drivers/pci:amdgpu/0000:05:00.0/available_compute_partition
SPX, DPX, QPX, CPX

cat /sys/module/amdgpu/drivers/pci:amdgpu/0000:05:00.0/available_memory_partition
NPS1, NPS2, NPS4
```

---

## Prone to Race condition when Partitioning

It seems to me that I'm observing a race condition in the GPU Partitioning via DCM procedure. Explanation here here, what I'm missing? Thanks

In the GPU Partitioning procedure, when we label the node we CANNOT wait for the DCM service to label back with success, because once the
kubectl logs -n openshift-amd-gpu -l app.kubernetes.io/name=device-config-manager logs shows "NodeModulesConfig for node $NODE_NAME deleted successfully"
it needs to untaint the node !! Even before verifying the partitioning, this is becasue DCM in the logs needs to detect the new memory partitioned
EVEN AFTER.

---

## Bug: DCM DaemonSet nodeSelector gates on KMM ready label

**Filed**: 2026-04-28

The DCM DaemonSet includes `kmm.node.kubernetes.io/<ns>.<name>.ready` in its `nodeSelector` (set in `internal/configmanager/configmanager.go` when `ShouldUseKMM` returns true). This creates a chicken-and-egg problem during partitioning:

1. Taint evicts KMM driver pod → KMM removes the `.ready` label
2. DCM DaemonSet no longer considers the node eligible → DCM pod can't schedule
3. Without DCM on the node, partitioning cannot proceed

The `feature.node.kubernetes.io/amd-gpu` label (set by node-labeller) is also removed after eviction, compounding the issue.

**Workaround**: manually re-add both labels after tainting.

**Upstream fix needed**: DCM should not require the KMM ready label in its nodeSelector, since it specifically needs to run when the driver is being reconfigured.

---

## Enhancement: To use control-plane toleration instead of amd-dcm

This would require to patch the controller and the DCM pod, so they don't die when tainting the node.
