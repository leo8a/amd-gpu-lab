# Basic NIC Validation

Basic tests to verify AMD NIC assignment and connectivity.

| Test                  | What it validates                                    |
| --------------------- | ---------------------------------------------------- |
| `00_nic-assignment/`  | NIC attachment to a pod via host-device CNI          |

## Prerequisites

- AMD Network Operator deployed
- Nodes labeled with `feature.node.kubernetes.io/amd-nic=true`

## Quick start

```bash
oc apply -k 00_nic-assignment/
```

See each subfolder's README for detailed verify and cleanup instructions.

## Cleanup

```bash
oc delete -k 00_nic-assignment/
```
