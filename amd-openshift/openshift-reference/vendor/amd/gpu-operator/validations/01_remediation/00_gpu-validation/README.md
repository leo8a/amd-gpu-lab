# GPU Validation Test

Runs a GPU validation test (the same check the remediation workflow performs in Step 7).

## Prerequisites

- AMD GPU Operator deployed
- Node Problem Detector deployed (`vendor/amd/node-problem-detector/`)
- Device Metrics Exporter >= v1.4.2 (inband-RAS support)
- Argo Workflows CRDs present (installed by OpenShift AI or manually)

## Run

```bash
# Step 1: Enable remediation on the DeviceConfig (merge patch, won't overwrite existing fields)
oc patch deviceconfig amdgpu-driver-install -n openshift-amd-gpu --type merge \
  --patch-file ../00_deviceconfig-remediation-patch.yaml

# Step 2: Deploy GPU validation test job
oc apply -k .
```

## Verify

```bash
# Check DeviceConfig remediation config
oc -n openshift-amd-gpu get deviceconfig amdgpu-driver-install -o jsonpath='{.spec.remediationWorkflow}' | python3 -m json.tool

# Watch the GPU validation test job
oc -n openshift-amd-gpu get job gpu-validation-test -w

# Check test results (Complete = all GPUs healthy, Failed = GPU issue detected)
oc -n openshift-amd-gpu logs job/gpu-validation-test

# Check test result events for granular per-GPU details
oc -n openshift-amd-gpu get events --field-selector reason=TestPassed,reason=TestFailed
```

## Cleanup

```bash
oc delete -k .
oc patch deviceconfig amdgpu-driver-install -n openshift-amd-gpu --type json \
  -p '[{"op": "remove", "path": "/spec/remediationWorkflow"}]'
```
