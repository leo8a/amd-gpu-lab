# Remediation E2E - Fault Injection

Triggers a full auto-remediation workflow by simulating a GPU hardware assertion via NPD fault injection on a single node.

**WARNING: This will taint, drain, and reboot the target GPU worker node.**

## Prerequisites

- AMD GPU Operator deployed with `remediationWorkflow.enable: true`
- Node Problem Detector deployed (`vendor/amd/node-problem-detector/`)
- Argo Workflows controller running (`vendor/amd/argo-workflows/`)
- Device Metrics Exporter >= v1.4.2

## What happens

1. NPD is restricted to the target node only (prevents affecting other nodes)
2. The ConfigMap replaces the real `amdgpuhealth` check with `/bin/false` (always exits 1)
3. NPD detects a "problem" within 30s, setting `AMDGPUHardwareAssertionHwa: True`
4. The GPU Operator triggers an Argo Workflow: taint → drain → reboot → GPU validation → untaint

## Run

```bash
TARGET_NODE="smc6216gpu.partner-accelerators.redhat.lab"

# Step 1: Restrict NPD to target node only
oc -n node-problem-detector patch daemonset node-problem-detector --type merge \
  -p "{\"spec\":{\"template\":{\"spec\":{\"nodeSelector\":{\"kubernetes.io/hostname\":\"$TARGET_NODE\"}}}}}"

# Step 2: Inject the fault config
oc apply -k .

# Step 3: Restart NPD to pick up the faulty config
oc -n node-problem-detector delete pod -l app=node-problem-detector

# Step 4: Watch the node condition flip to True (~30s)
watch "oc get nodes -o custom-columns='NODE:.metadata.name,HWA:.status.conditions[?(@.type==\"AMDGPUHardwareAssertionHwa\")].status'"

# Step 5: Watch the remediation workflow
oc -n openshift-amd-gpu get workflows -w
```

## Monitor

```bash
# Workflow steps
oc -n openshift-amd-gpu get pods -l workflows.argoproj.io/workflow -w

# Node taints
oc get nodes -o custom-columns='NODE:.metadata.name,TAINTS:.spec.taints[*].key'
```

## Cleanup (restore real NPD config and DaemonSet)

**Run cleanup BEFORE the node finishes rebooting**, otherwise NPD will re-detect the
fake fault and trigger another remediation cycle (reboot loop).

```bash
# Restore the original NPD config
oc apply -f ../../../../node-problem-detector/04_npd-config.yaml

# Restore NPD to run on all GPU nodes
oc -n node-problem-detector patch daemonset node-problem-detector --type json \
  -p '[{"op":"remove","path":"/spec/template/spec/nodeSelector/kubernetes.io~1hostname"}]'

# Restart NPD
oc -n node-problem-detector rollout restart daemonset/node-problem-detector
```
