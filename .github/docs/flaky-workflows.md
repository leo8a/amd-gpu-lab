# Flaky Workflows

Tracked CI instabilities where the OpenShift runtime provides insufficient diagnostics and root-cause analysis requires driver-level or out-of-band investigation.

## GPU Operator

### DCM partitioning

- **DPX + NPS2 on smc6217gpu (MI325X, Supermicro AS-8126GS-TNMR2)** — Observed on OpenShift 4.21 with the AMD GPU Operator and DCM controller on Supermicro MI325X nodes. Partitioning to `dpx-profile-nps2` succeeds, but restoring back to SPX + NPS1 breaks the DCM pod. The memory partition call fails with `"Failed to memory partition Call succeeded."` and the pod enters a recovery loop that times out after 5 minutes, crashing and breaking the rest of the workflow. The driver reports `NPS2` as the existing partition but cannot transition to `NPS1`; the recovery step (deleting `NodeModulesConfig` and reloading via KMM) does not resolve it. Likely a driver-level issue with NPS mode transitions from NPS2 on MI325X; requires out-of-band host `dmesg`/`amdgpu` logs and BMC event correlation. CI now uses CPX + NPS4 instead.

## Network Operator

No known flaky workflows.
