# SR-IOV Validation

Validates SR-IOV Virtual Function (VF) assignment to pods using AMD Pensando AI NICs.

Two NIC profiles are covered, each in its own subfolder:

| Test                      | What it validates                                              |
| ------------------------- | -------------------------------------------------------------- |
| `00_pf1_vf1-profile/`    | 1 VF per PF — standard SR-IOV with RDMA support               |
| `01_hnic_pf1_vf8-profile/`| 8 VFs per PF — higher density SR-IOV without RDMA             |

## Prerequisites

- AMD Network Operator deployed
- OpenShift SR-IOV Network Operator installed
- NIC profile updated to match the test (`pf1_vf1` or `hnic_pf1_vf8`)
- Node rebooted after profile update
- Nodes labeled with `feature.node.kubernetes.io/amd-nic=true`

## Quick start

```bash
oc apply -k 00_pf1_vf1-profile/        # 1 VF per PF (with RDMA)
oc apply -k 01_hnic_pf1_vf8-profile/   # 8 VFs per PF (no RDMA)
```

See each subfolder's README for detailed prerequisites, verify, and cleanup instructions.

## Cleanup

```bash
oc delete -k 00_pf1_vf1-profile/
oc delete -k 01_hnic_pf1_vf8-profile/
```
