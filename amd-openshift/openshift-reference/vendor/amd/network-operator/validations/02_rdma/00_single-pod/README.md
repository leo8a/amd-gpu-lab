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

- All RDMA devices on the node visible under `/sys/class/infiniband` (e.g. `ionic_0`–`ionic_6` plus any non-AMD devices like `mlx5_0`)
- Device type: `1: CA` (Channel Adapter)
- RDMA network interface: `net1` with IP from 192.168.200.0/24

`oc logs -n openshift-amd-network rdma-test` (smc6216gpu, 7 AMD ionic + 1 Mellanox):

```logs
=== RDMA Device Check ===
Device: ionic_0
  Type: 1: CA
  GUID: 0690:81ff:fe36:9960
Device: ionic_1
  Type: 1: CA
  GUID: 0690:81ff:fe36:a878
Device: ionic_2
  Type: 1: CA
  GUID: 0690:81ff:fe36:7068
Device: ionic_3
  Type: 1: CA
  GUID: 0690:81ff:fe36:ae48
Device: ionic_4
  Type: 1: CA
  GUID: 0690:81ff:fe36:6ed0
Device: ionic_5
  Type: 1: CA
  GUID: 0690:81ff:fe36:7278
Device: ionic_6
  Type: 1: CA
  GUID: 0690:81ff:fe36:7308
Device: mlx5_0
  Type: 1: CA
  GUID: 5000:e603:00a9:7630

=== Network Interfaces ===
net1: 192.168.200.1/24

=== RDMA Validation: PASSED ===
```

## Cleanup

```bash
oc delete -k .
```

## Files

- `00_nad-amd-rdma.yaml` - NetworkAttachmentDefinition for RDMA network
- `01_single-pod-test.yaml` - Single pod RDMA device validation
