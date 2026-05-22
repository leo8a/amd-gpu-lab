# RDMA Validation

Validates AMD NIC assignment, RDMA device visibility, and bandwidth with AMD Pensando AI NICs using the host-device CNI.

| Test             | What it validates                                                                 |
| ---------------- | --------------------------------------------------------------------------------- |
| `00_single-pod/` | NIC attachment, RDMA device visibility, link speed                                |
| `01_multi-node/` | RDMA write bandwidth between two nodes via `ib_write_bw` (perftest, host memory)  |

## Prerequisites

- AMD Network Operator deployed
- Nodes labeled with `feature.node.kubernetes.io/amd-nic=true`
- For `01_multi-node/`: at least 2 nodes with AMD NICs physically connected (carrier up)
- Container image `quay.io/lochoa/amd-tools:latest` (see `01_multi-node/tools/` for build instructions)

## Quick start

```bash
make all              # run all tests
make single-pod       # single-pod RDMA device check
make multi-node       # two-node RDMA bandwidth test (ib_write_bw)
make cleanup          # delete all test resources
```

## Cleanup

```bash
make cleanup
```
