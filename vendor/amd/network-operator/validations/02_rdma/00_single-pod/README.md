# Single Pod RDMA Device Test

Simple test to verify RDMA device visibility on a single pod.

## Prerequisites

- AMD Network Operator deployed
- Nodes labeled with `feature.node.kubernetes.io/amd-nic=true`

## Run Test

```bash
oc apply -k .
oc logs -f -n openshift-amd-network rdma-test
```

## Expected Output

- RDMA device visible (`ionic_X`)
- Device type: `1: CA` (Channel Adapter)
- RDMA network interface: `net1` with IP from 192.168.200.0/24

Example:

```logs
=== RDMA Device Check ===
Device: ionic_1
  Type: 1: CA
  GUID: 0690:81ff:fe36:9960

=== Network Interfaces ===
net1: 192.168.200.2/24

=== RDMA Validation: PASSED ===
```

## Cleanup

```bash
oc delete -k .
```

## Files

- `00_nad-amd-rdma.yaml` - NetworkAttachmentDefinition for RDMA network
- `01_single-pod-test.yaml` - Single pod RDMA device validation
