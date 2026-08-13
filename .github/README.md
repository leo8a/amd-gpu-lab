# AMD Operators Validations CI

[![GPU Operator](https://github.com/leo8a/amd-gpu-lab/actions/workflows/nightly-gpu-validations.yaml/badge.svg)](https://github.com/leo8a/amd-gpu-lab/actions/workflows/nightly-gpu-validations.yaml)
[![Network Operator](https://github.com/leo8a/amd-gpu-lab/actions/workflows/nightly-network-validations.yaml/badge.svg)](https://github.com/leo8a/amd-gpu-lab/actions/workflows/nightly-network-validations.yaml)

Nightly workflows that run AMD GPU and network operator validations on a self-hosted runner.

## GPU operator stages

Workflow: `nightly-gpu-validations.yaml` — runs at 00:00 UTC.

The pipeline is ordered so each DRA test runs when GPUs are in the correct state:

```logs
preflight → dra-full-gpu → partition → dra-partitioned-gpu → restore → cleanup
```

| Stage | Name                 | What it validates                      | GPU state      | Duration |
| ----- | -------------------- | -------------------------------------- | -------------- | -------- |
| 0     | DRA Full GPU         | DRA resource claim for full GPU        | SPX (default)  | ~5 min   |
| 1     | Partition smc6216gpu | Partition to CPX + NPS4                | —              | ~10 min  |
| 2     | Partition smc6217gpu | Partition to DPX + NPS2                | —              | ~10 min  |
| 3     | DRA Partitioned      | DRA resource claim for partitioned GPU | CPX/DPX        | ~5 min   |
| 4     | Restore smc6216gpu   | Restore to SPX + NPS1                  | —              | ~10 min  |
| 5     | Restore smc6217gpu   | Restore to SPX + NPS1                  | —              | ~10 min  |

Nightly default: stages 0–5. Stages are selectable via manual dispatch.

## Network operator stages

Workflow: `nightly-network-validations.yaml` — runs at 01:00 UTC.

### Install

| Stage | Name                   | What it does                                           | Duration |
| ----- | ---------------------- | ------------------------------------------------------ | -------- |
| 0     | Install Network Operator | Deploy operator, wait for CSV, verify device plugin  | ~5 min   |

### RDMA validation (sequential, each with cleanup)

| Stage | Name                     | What it validates                                     | Duration |
| ----- | ------------------------ | ----------------------------------------------------- | -------- |
| 1     | RDMA Single Pod          | RDMA device visibility and NIC attachment             | ~3 min   |
| 2     | RDMA Multi-Node CPU      | CPU-to-CPU RDMA bandwidth via ib_write_bw             | ~3 min   |
| 3     | RDMA Multi-Node GDR      | GPU-to-GPU RDMA bandwidth (GPU-Direct RDMA)           | ~3 min   |
| 4     | RDMA Multi-Node GDR+DRA  | GDR with DRA-based GPU/NIC PCIe root alignment        | ~5 min   |

### Cluster Validation Framework (after RDMA)

| Stage | Name                           | What it validates                               | Duration |
| ----- | ------------------------------ | ----------------------------------------------- | -------- |
| 5     | CVF: RCCL Collective Comms     | GPU health + RCCL performance (MPI, multi-node) | ~20 min  |

Uses the [AMD Cluster Validation Framework](https://instinct.docs.amd.com/projects/network-operator/en/latest/cluster_validation_framework/README.html) with Kubeflow MPI Operator for distributed RCCL allreduce/allgather benchmarks across nodes.

Nightly default: all stages (0–5). Stages are selectable via manual dispatch.

## Manual dispatch

Trigger via GitHub Actions UI or CLI:

```bash
# GPU operator
gh workflow run nightly-gpu-validations.yaml \
  -R leo8a/amd-gpu-lab \
  -f stages="0"

# Network operator
gh workflow run nightly-network-validations.yaml \
  -R leo8a/amd-gpu-lab \
  -f stages="0,1"
```
