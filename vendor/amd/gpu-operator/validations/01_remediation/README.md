# Remediation Validation

Validates GPU auto-remediation end-to-end with the AMD GPU Operator.

Two test scenarios are covered, each in its own subfolder:

| Test                       | What it validates                                                                            |
| -------------------------- | -------------------------------------------------------------------------------------------- |
| `00_gpu-validation/`       | Enables remediation on DeviceConfig and runs the GPU health check (RVS gst_single)           |
| `01_e2e-fault-injection/`  | Injects a fake GPU fault via NPD to trigger a full remediation workflow (taint/drain/reboot) |

## Prerequisites

- AMD GPU Operator deployed
- Node Problem Detector deployed (`vendor/amd/node-problem-detector/`)
- Device Metrics Exporter >= v1.4.2 (inband-RAS support)
- Argo Workflows CRDs present (installed by OpenShift AI or manually)
- For the E2E test: `remediationWorkflow.enable: true` on DeviceConfig (applied by `00_gpu-validation/`)

## Quick start

```bash
# Step 1: Enable remediation on the DeviceConfig (shared patch)
oc patch deviceconfig amdgpu-driver-install -n openshift-amd-gpu --type merge \
  --patch-file 00_deviceconfig-remediation-patch.yaml

# Step 2: Run a specific test
oc apply -k 00_gpu-validation/          # GPU health check
oc apply -k 01_e2e-fault-injection/     # full E2E fault injection (WARNING: reboots target node)
```

See each subfolder's README for detailed verify and cleanup instructions.

## Restore DeviceConfig

```bash
oc patch deviceconfig amdgpu-driver-install -n openshift-amd-gpu --type json \
  -p '[{"op": "remove", "path": "/spec/remediationWorkflow"}]'
```
