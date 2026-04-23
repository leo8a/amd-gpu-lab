# Network Operator Validations CI

Nightly workflow that runs AMD network-operator validation stages on a self-hosted runner at 04:00 UTC.

## Stages

| Stage | Name                 | What it validates                          | Duration |
| ----- | -------------------- | ------------------------------------------ | -------- |
| 0     | Basic NIC            | NIC assignment via host-device CNI         | ~2 min   |
| 1     | Cluster Validation   | GPU health + RCCL performance (MPI)        | ~20 min  |
| 2     | RDMA Single Pod      | RDMA device visibility in a pod            | ~1 min   |
| 3     | RDMA Multi-Node      | Two-node RDMA connectivity (needs 2+ nodes)| ~2 min   |
| 4     | SR-IOV (pf1_vf1)     | SR-IOV VF assignment (1 VF/NIC, RDMA)      | ~5 min   |
| 5     | SR-IOV (hnic_pf1_vf8)| SR-IOV VF assignment (8 VFs/NIC, no RDMA)  | ~5 min   |

Nightly default: stages 0, 1, 2, 4. Stages 3 and 5 are available via manual dispatch.

## Running locally

Requires `oc` authenticated against the target cluster.

```bash
# Single stage
.github/scripts/run-validation-stage.sh 0

# Multiple stages sequentially
for s in 0 1 2 4; do .github/scripts/run-validation-stage.sh "$s"; done
```

Override defaults with environment variables:

```bash
NAMESPACE=my-ns LOG_DIR=./logs .github/scripts/run-validation-stage.sh 2
```

Logs are written to `$LOG_DIR/stage-<N>/` (defaults to `/tmp/validation-logs/`).

## Manual dispatch

Trigger via GitHub Actions UI or CLI:

```bash
gh workflow run nightly-network-validations.yaml \
  -f stages="0,2" \
  -f sriov_profile="skip"
```
