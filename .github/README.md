# Network Operator Validations CI

Nightly workflow that runs AMD network-operator validation stages on a self-hosted runner at 04:00 UTC.

## Stages

| Stage | Name                  | What it validates                           | Duration |
| ----- | --------------------- | ------------------------------------------- | -------- |
| 0     | Cluster Validation    | GPU health + RCCL performance (MPI)         | ~20 min  |
| 1     | Basic NIC             | NIC assignment via host-device CNI          | ~2 min   |
| 2     | RDMA Single Pod       | RDMA device visibility in a pod             | ~1 min   |
| 3     | RDMA Multi-Node       | Two-node RDMA connectivity (needs 2+ nodes) | ~2 min   |
| 4     | SR-IOV (pf1_vf1)      | SR-IOV VF assignment (1 VF/NIC, RDMA)       | ~5 min   |
| 5     | SR-IOV (hnic_pf1_vf8) | SR-IOV VF assignment (8 VFs/NIC, no RDMA)   | ~5 min   |

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
  -R leo8a/amd-gpu-lab \
  -f stages="0,2" \
  -f sriov_profile="skip"
```

## Source of truth

The **canonical repository** is the local workstation at `/home/leo8a/Projects/amd-gpu-lab/`. All edits happen here first. The GitHub repo (`leo8a/amd-gpu-lab`) is a downstream mirror that receives `.github/` and `validations/` via a temp-clone push. The workflow uses `actions/checkout` so the self-hosted runner gets everything it needs from Git — no manual scp sync required.

Never edit files directly on GitHub or on the runner — changes flow one way from the local repo.

## Deployment workflow

### 1. Edit files locally

All source files are in `/home/leo8a/Projects/amd-gpu-lab/`. Edit the workflow, scripts, or validation manifests there.

### 2. Push to GitHub

The GitHub repo is maintained via a temp clone (the local repo has no git remote pointing to it). Create a fresh clone or reuse an existing one:

```bash
TMPDIR=$(mktemp -d) && cd "$TMPDIR"
git clone https://github.com/leo8a/amd-gpu-lab.git && cd amd-gpu-lab
```

Copy the updated files and push:

```bash
cp -r /home/leo8a/Projects/amd-gpu-lab/.github/* .github/
cp -r /home/leo8a/Projects/amd-gpu-lab/validations ./validations
git add -A && git commit -m "ci: <description of changes>"
git push
```

### 3. Test

```bash
gh workflow run nightly-network-validations.yaml -R leo8a/amd-gpu-lab -f stages="0" -f sriov_profile="skip"
gh run list -R leo8a/amd-gpu-lab -w "Nightly AMD Network Operator Validations" -L 1
```

## File layout

```
.github/
  workflows/
    nightly-network-validations.yaml   # workflow definition
  scripts/
    run-validation-stage.sh            # validation stage runner (stages 0-5)
  docs/
    self-hosted-runner-setup.md        # runner installation guide
  README.md                           # this file
validations/
  00_cluster-validation/               # stage 0 manifests
  01_basic/
    00_nic-assignment/                 # stage 1 manifests
  02_rdma/
    00_single-pod/                     # stage 2 manifests
    01_multi-node/                     # stage 3 manifests
  03_sriov/
    00_pf1_vf1-profile/               # stage 4 manifests
    01_hnic_pf1_vf8-profile/          # stage 5 manifests
```
