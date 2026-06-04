# AMD Operators Validations CI

[![GPU Operator](https://github.com/leo8a/amd-gpu-lab/actions/workflows/nightly-gpu-validations.yaml/badge.svg)](https://github.com/leo8a/amd-gpu-lab/actions/workflows/nightly-gpu-validations.yaml)
[![Network Operator](https://github.com/leo8a/amd-gpu-lab/actions/workflows/nightly-network-validations.yaml/badge.svg)](https://github.com/leo8a/amd-gpu-lab/actions/workflows/nightly-network-validations.yaml)

Nightly workflows that run AMD GPU and network operator validations on a self-hosted runner.

## GPU operator stages

Workflow: `nightly-gpu-validations.yaml` — runs at 00:00 UTC.

### DCM partitioning (always runs)

| Stage | Name                 | What it validates         | Duration |
| ----- | -------------------- | ------------------------- | -------- |
| 0     | Partition smc6216gpu | Partition to CPX + NPS4   | ~10 min  |
| 1     | Partition smc6217gpu | Partition to DPX + NPS2   | ~10 min  |
| 2     | Restore smc6216gpu   | Restore to SPX + NPS1     | ~10 min  |
| 3     | Restore smc6217gpu   | Restore to SPX + NPS1     | ~10 min  |

### DRA validation (after restore)

| Stage | Name            | What it validates                      | Duration |
| ----- | --------------- | -------------------------------------- | -------- |
| 4     | DRA Full GPU    | DRA resource claim for full GPU        | ~5 min   |
| 5     | DRA Partitioned | DRA resource claim for partitioned GPU | ~5 min   |

Nightly default: stages 0–5. Stages are selectable via manual dispatch.

## Network operator stages

Workflow: `nightly-network-validations.yaml` — runs at 01:00 UTC.

### RDMA validation (stages run in parallel)

| Stage | Name                | What it validates                         | Duration |
| ----- | ------------------- | ----------------------------------------- | -------- |
| 0     | RDMA Single Pod     | RDMA device visibility and NIC attachment | ~3 min   |
| 1     | RDMA Multi-Node CPU | CPU-to-CPU RDMA bandwidth via ib_write_bw | ~3 min   |
| 2     | RDMA Multi-Node GDR | GPU-to-GPU RDMA bandwidth (GDR)           | ~3 min   |

### Cluster Validation Framework (after RDMA)

| Stage | Name                         | What it validates                               | Duration |
| ----- | ---------------------------- | ----------------------------------------------- | -------- |
| 3     | Cluster Validation Framework | GPU health + RCCL performance (MPI, multi-node) | ~20 min  |

See the [AMD Cluster Validation Framework documentation](https://instinct.docs.amd.com/projects/network-operator/en/latest/cluster_validation_framework/README.html) for details.

Nightly default: all stages (0–3). Stages are selectable via manual dispatch.

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
