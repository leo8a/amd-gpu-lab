# AMD Operators Validations CI

Nightly workflows that run AMD GPU and network operator validations on a self-hosted runner.

## GPU operator stages

Workflow: `nightly-gpu-validations.yaml` — runs at 03:00 UTC.

### DCM partitioning (always runs)

| Job                    | Node       | Profile        | Purpose          |
| ---------------------- | ---------- | -------------- | ---------------- |
| partition-smc6216gpu   | smc6216gpu | SPX + NPS1     | Test non-default |
| partition-smc6217gpu   | smc6217gpu | DPX + NPS2     | Test non-default |
| restore-smc6216gpu     | smc6216gpu | CPX + NPS4     | Restore default  |
| restore-smc6217gpu     | smc6217gpu | SPX + NPS1     | Restore default  |

### DRA validation (after restore)

| Stage | Name            | What it validates                  | Duration |
| ----- | --------------- | ---------------------------------- | -------- |
| 0     | DRA Full GPU    | DRA resource claim for full GPU    | ~5 min   |
| 1     | DRA Partitioned | DRA resource claim for partitioned | ~5 min   |

Nightly default: DCM partitioning + all DRA stages. DRA stages are selectable via manual dispatch.

## Network operator stages

Workflow: `nightly-network-validations.yaml` — runs at 04:00 UTC.

| Stage | Name               | What it validates                               | Duration |
| ----- | ------------------ | ----------------------------------------------- | -------- |
| 0     | RDMA Single Pod    | RDMA device visibility and NIC attachment       | ~3 min   |
| 1     | RDMA Multi-Node    | Two-node RDMA bandwidth via ib_write_bw         | ~3 min   |
| 2     | Cluster Validation | GPU health + RCCL performance (MPI, multi-node) | ~20 min  |

Nightly default: all stages (0, 1, 2). Individual stages are selectable via manual dispatch.

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
