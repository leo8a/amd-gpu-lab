# Basic NIC Assignment Test

Simple test to verify basic AMD NIC assignment to a pod using host-device CNI.

## Prerequisites

- AMD Network Operator deployed
- Nodes labeled with `feature.node.kubernetes.io/amd-nic=true`

## Run Test

```bash
oc apply -k .
oc exec -it -n openshift-amd-network test-amd-nic -- bash
```

## Expected Behavior

- Pod gets direct access to AMD NIC via host-device CNI
- Secondary network interface configured
- Manual verification required (interactive shell pod)

## Inside Pod

```bash
# Check network interfaces
ip addr show

# Verify NIC assignment
ls /sys/class/net/
```

## Cleanup

```bash
oc delete -k .
```

## Files

- `00_nad-amd-nic-basic.yaml` - NetworkAttachmentDefinition for basic NIC assignment
- `01_basic-nic-test.yaml` - Interactive test pod
