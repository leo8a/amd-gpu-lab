# RDMA Validation

Validates AMD NIC assignment, RDMA device visibility, and bandwidth with AMD Pensando Pollara 400 AI NICs using the host-device CNI.

## Tests

| Test                 | What it validates                                                  | Details                                          |
| -------------------- | ------------------------------------------------------------------ | ------------------------------------------------ |
| `00_single-pod/`         | NIC attachment, RDMA device visibility, link speed                        | Single pod, no connectivity needed               |
| `01_multi-node-cpu/`     | CPU-to-CPU RDMA write bandwidth via `ib_write_bw`                        | [README](01_multi-node-cpu/README.md)            |
| `02_multi-node-gdr/`     | GPU-to-GPU RDMA write bandwidth via `ib_write_bw --use_rocm=0`           | [README](02_multi-node-gdr/README.md)            |
| `03_multi-node-gdr-dra/` | GDR with DRA PCIe root alignment (GPU+NIC same PCIe switch, experimental) | [README](03_multi-node-gdr-dra/README.md)        |

## Prerequisites

| Requirement              | Details                                                                                                         |
| ------------------------ | --------------------------------------------------------------------------------------------------------------- |
| AMD Network Operator     | Deployed and running                                                                                            |
| Node labels              | `feature.node.kubernetes.io/amd-nic=true`                                                                       |
| AI NIC profile           | `default` (Non-breakout mode 1x400G, no VFs)                                                                    |
| NIC QoS                  | Auto-neg disabled, PFC, DCQCN — see [nic-prereqs.md](docs/nic-prereqs.md). **Does not persist across reboots.** |
| Physical connectivity    | At least 2 nodes with AI NICs connected (carrier up) — required for multi-node tests                            |
| Container images         | `quay.io/lochoa/amd-tools:latest` (CPU), `quay.io/lochoa/amd-tools:gdr` (GDR)                                   |

## Expected Results (Dell XE9785L / MI355X, OCP 4.21)

| Test                 | BW (Gb/s) | Device  | Notes                               |
| -------------------- | --------- | ------- | ----------------------------------- |
| `single-pod`         | —         | —       | 8 ionic + 4 mlx5 visible, 400G link |
| `multi-node-cpu`     | ~397      | ionic_6 | 8 QPs, 1 MB messages                |
| `multi-node-gdr`     | ~313      | ionic_1 | GPU VRAM (gfx950), NUMA-aligned     |
| `multi-node-gdr-dra` | ~391      | ionic_0 | DRA PCIe root-aligned GPU+NIC       |

## Quick Start

```bash
make single-pod       # single-pod RDMA device check
make multi-node-cpu   # two-node CPU RDMA bandwidth test
make multi-node-gdr       # two-node GPU RDMA bandwidth test (GDR)
make multi-node-gdr-dra   # two-node GDR with DRA PCIe root alignment (experimental)
make cleanup              # delete all test resources
```

## Reference

- [AMD Pensando Pollara AI 400G NIC Operations Guide (UG1801)](https://docs.amd.com/r/en-US/ug1801-ai-nic-pollara-400-ops-guide)
- [AMD Pollara 400 Benchmarking Guide (UG1813)](https://docs.amd.com/r/en-US/ug1813-pollara-400-benchmarking-guide)
- [NIC prerequisites](docs/nic-prereqs.md) — per-port and per-device QoS commands
- [Tuning notes](docs/tunning-notes.md) — MTU, queue pair, and message size tuning results
