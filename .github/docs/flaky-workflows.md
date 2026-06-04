# Flaky Workflows

Tracked CI instabilities where the OpenShift runtime provides insufficient diagnostics and root-cause analysis requires driver-level or out-of-band investigation.

## GPU Operator

### DCM partitioning

- **DCM partitioning on smc6217gpu (MI325X, Supermicro AS-8126GS-TNMR2)** — DCM partitioning on this node is flaky with both DPX + NPS2 and CPX + NPS4 profiles. With `dpx-profile-nps2`, partitioning succeeds but restoring back to SPX + NPS1 breaks the DCM pod — the memory partition call fails with `"Failed to memory partition Call succeeded."` and the pod enters a recovery loop that times out after 5 minutes. With `cpx-profile-nps4`, similar instability has been observed. The driver reports the existing NPS mode but cannot transition back to `NPS1`; the recovery step (deleting `NodeModulesConfig` and reloading via KMM) does not resolve it. May be caused by an outdated BIOS version on this node; needs further investigation including out-of-band host `dmesg`/`amdgpu` logs and BMC event correlation.

## Network Operator

No known flaky workflows.
