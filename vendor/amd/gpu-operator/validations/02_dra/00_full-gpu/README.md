# DRA Full GPU Validation

Allocates a single full AMD GPU via a DRA `ResourceClaimTemplate` and the `gpu.amd.com` DeviceClass, then runs `rocm-smi` to confirm the GPU is visible and healthy.

## Prerequisites

- AMD GPU Operator >= 1.5.0 deployed with DRA enabled (see `../00_deviceconfig-dra-patch.yaml`)
- OpenShift 4.18+ / Kubernetes 1.32+ with `DynamicResourceAllocation` feature gate enabled
- CDI (Container Device Interface) enabled in the container runtime
- AMD GPU driver (amdgpu kernel module) loaded on worker nodes

## Run

```bash
# Step 1: Enable DRA on the DeviceConfig (if not already done)
oc patch deviceconfig amdgpu-driver-install -n openshift-amd-gpu --type merge \
  --patch-file ../00_deviceconfig-dra-patch.yaml

# Step 2: Wait for the DRA driver DaemonSet to be ready
oc -n openshift-amd-gpu get daemonset -l app=dra-driver -w

# Step 3: Deploy the full GPU test
oc apply -k .
```

## Verify

```bash
# Check that the DeviceClass exists
oc get deviceclass gpu.amd.com

# Check that ResourceSlices are published
oc get resourceslices -l driver=gpu.amd.com

# Inspect full GPU (SPX) device attributes
oc get resourceslices -o json | jq '.items[] | select(.spec.devices[]?.attributes.type.string == "amdgpu") | .spec.devices[] | {name, type: .attributes.type.string, profile: .attributes.partitionProfile.string, cu: .capacity.computeUnits.value, mem: .capacity.memory.value}'

# Watch the test job
oc -n openshift-amd-gpu get job dra-full-gpu-test -w

# Check results (Complete = GPU healthy, Failed = GPU issue)
oc -n openshift-amd-gpu logs job/dra-full-gpu-test
```

### ResourceSlice example (SPX / NPS1)

With the default SPX partition (no partitioning), the DRA driver publishes each physical GPU
as a single device with `type: "amdgpu"` and the full GPU resources (304 CUs, 1216 SIMDs,
256Gi VRAM for MI325X):

```json
{
  "name": "gpu-1-128",
  "attributes": {
    "type":             { "string": "amdgpu" },
    "partitionProfile": { "string": "spx_nps1" },
    "productName":      { "string": "AMD_Instinct_MI325_OAM" },
    "family":           { "string": "AI" },
    "pciAddr":          { "string": "0000:05:00.0" },
    "driverVersion":    { "version": "6.16.6" },
    "cardIndex":        { "int": 1 },
    "renderIndex":      { "int": 128 }
  },
  "capacity": {
    "computeUnits": { "value": "304" },
    "simdUnits":    { "value": "1216" },
    "memory":       { "value": "262128Mi" }
  }
}
```

## Expected output

```bash
=== DRA Full GPU Validation ===
--- rocm-smi ---

=========================================== ROCm System Management Interface ===========================================
===================================================== Concise Info =====================================================
Device  Node  IDs              Temp        Power     Partitions          SCLK  MCLK    Fan  Perf  PwrCap   VRAM%  GPU%
              (DID,     GUID)  (Junction)  (Socket)  (Mem, Compute, ID)
========================================================================================================================
0       8     0x74a5,   20463  38.0°C      135.0W    NPS1, SPX, 0        None  900Mhz  0%   auto  1000.0W  0%     0%
========================================================================================================================
================================================= End of ROCm SMI Log ==================================================
--- rocm-smi --showid ---

============================ ROCm System Management Interface ============================
=========================================== ID ===========================================
GPU[0]		: Device Name: 		AMD Instinct MI325X
GPU[0]		: Device ID: 		0x74a5
GPU[0]		: Device Rev: 		0x00
GPU[0]		: Subsystem ID: 	0x74a5
GPU[0]		: GUID: 		20463
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
