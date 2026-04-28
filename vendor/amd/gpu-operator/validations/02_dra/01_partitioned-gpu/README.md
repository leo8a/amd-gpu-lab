# DRA Partitioned GPU Validation

Allocates a single GPU partition (e.g. CPX) via a DRA `ResourceClaimTemplate` with a CEL selector, then runs `rocm-smi` to confirm the partition is visible and correctly configured.

> **Note:** GPU virtualization (vGPU / Virt) is **not supported** with AMD DRA at this time.

## Prerequisites

- AMD GPU Operator >= 1.5.0 deployed with DRA enabled (see `../00_deviceconfig-dra-patch.yaml`)
- OpenShift 4.18+ / Kubernetes 1.32+ with `DynamicResourceAllocation` feature gate enabled
- CDI (Container Device Interface) enabled in the container runtime
- AMD GPU driver (amdgpu kernel module) loaded on worker nodes
- GPU partitioning configured via Device Config Manager (e.g. `computePartition: CPX`)

## Run

```bash
# Step 1: Enable DRA on the DeviceConfig (if not already done)
oc patch deviceconfig amdgpu-driver-install -n openshift-amd-gpu --type merge \
  --patch-file ../00_deviceconfig-dra-patch.yaml

# Step 2: Wait for the DRA driver DaemonSet to be ready
oc -n openshift-amd-gpu get daemonset -l app=dra-driver -w

# Step 3: Deploy the partitioned GPU test
oc apply -k .
```

## Verify

```bash
# Check that ResourceSlices with partition devices are published
oc get resourceslices

# Inspect partition attributes (type, profile, capacity)
oc get resourceslices -o json | jq '.items[] | select(.spec.devices[]?.attributes.type.string == "amdgpu-partition") | .spec.devices[] | {name, type: .attributes.type.string, profile: .attributes.partitionProfile.string, cu: .capacity.computeUnits.value, mem: .capacity.memory.value}'

# Watch the test job
oc -n openshift-amd-gpu get job dra-partitioned-gpu-test -w

# Check results (Complete = partition healthy, Failed = issue detected)
oc -n openshift-amd-gpu logs job/dra-partitioned-gpu-test
```

### ResourceSlice example (CPX / NPS4)

When GPUs are partitioned with CPX and NPS4, the DRA driver publishes each partition as a
separate device with `type: "amdgpu-partition"`. Each partition gets 1/8 of the full GPU
resources (38 CUs, 152 SIMDs, 32Gi VRAM for MI325X):

```json
{
  "name": "gpu-17-144",
  "attributes": {
    "type":             { "string": "amdgpu-partition" },
    "partitionProfile": { "string": "cpx_nps4" },
    "productName":      { "string": "AMD_Instinct_MI325_OAM" },
    "family":           { "string": "AI" },
    "parentPciAddr":    { "string": "0000:65:00.0" },
    "driverVersion":    { "version": "6.16.6" },
    "cardIndex":        { "int": 17 },
    "renderIndex":      { "int": 144 }
  },
  "capacity": {
    "computeUnits": { "value": "38" },
    "simdUnits":    { "value": "152" },
    "memory":       { "value": "32Gi" }
  }
}
```

Compare with a full GPU (SPX) device which has `type: "amdgpu"`, 304 CUs, 1216 SIMDs, and
256Gi VRAM.

## Expected output

```bash
=== DRA Partitioned GPU Validation ===
--- rocm-smi ---

============================================ ROCm System Management Interface ============================================
====================================================== Concise Info ======================================================
Device  Node  IDs              Temp        Power     Partitions          SCLK    MCLK    Fan  Perf  PwrCap   VRAM%  GPU%
              (DID,     GUID)  (Junction)  (Socket)  (Mem, Compute, ID)
==========================================================================================================================
0       18    0x74a5,   47503  40.0°C      144.0W    NPS4, CPX, 0        131Mhz  900Mhz  0%   auto  1000.0W  0%     0%
==========================================================================================================================
================================================== End of ROCm SMI Log ===================================================
--- rocm-smi --showcomputepartition ---

============================ ROCm System Management Interface ============================
=============================== Current Compute Partition ================================
GPU[0]		: Compute Partition: CPX
==========================================================================================
================================== End of ROCm SMI Log ===================================
=== PASS ===
```

## Cleanup

```bash
oc delete -k .

# Restore the base DeviceConfig (Device Plugin enabled, DRA disabled)
oc apply -f ../../../07_amd-deviceconfig.yaml
```
