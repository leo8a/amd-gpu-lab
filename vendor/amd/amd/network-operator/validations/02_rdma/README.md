# RDMA Validation

Validates RDMA device visibility and network connectivity with AMD Pensando AI NICs.

Two test scenarios are covered, each in its own subfolder:

| Test              | What it validates                                                       |
| ----------------- | ----------------------------------------------------------------------- |
| `00_single-pod/`  | RDMA device visible inside a single pod (`/sys/class/infiniband`)       |
| `01_multi-node/`  | RDMA connectivity between two pods on different nodes (server + client) |

## Prerequisites

- AMD Network Operator deployed
- Nodes labeled with `feature.node.kubernetes.io/amd-nic=true`
- For `01_multi-node/`: at least 2 nodes with AMD NICs physically connected (carrier up)

## Quick start

```bash
oc apply -k 00_single-pod/       # single-pod RDMA device check
oc apply -k 01_multi-node/       # two-node RDMA connectivity test
```

See each subfolder's README for detailed verify and cleanup instructions.

## Cleanup

```bash
oc delete -k 00_single-pod/
oc delete -k 01_multi-node/
```
