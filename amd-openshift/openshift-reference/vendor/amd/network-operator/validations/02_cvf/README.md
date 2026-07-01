# AMD Cluster Validation Framework (CVF)

Validates GPU health (RVS `gst_single`) and multi-node RDMA/RCCL performance (`all_reduce_perf`, `broadcast_perf`, `reduce_scatter_perf`) across AMD MI325X nodes on OpenShift.

Based on the [AMD Network Operator Cluster Validation Framework](https://instinct.docs.amd.com/projects/network-operator/en/latest/cluster_validation_framework/README.html).

## What It Does

1. Deploys Kubeflow MPI Operator (v0.8.0) for distributed job execution
2. Creates ConfigMaps for config, MPIJob template, test-runner template, and fluentbit
3. Deploys a CronJob with `submit-mpijob` and `fluent-bit` containers
4. Runs GPU health checks (RVS) on each candidate node, then multi-node RCCL benchmarks via MPIJobs
5. Applies node labels based on validation results

## Quick Start

```bash
make deploy     # Deploy MPI Operator, CronJob, ConfigMaps
make run        # Trigger a manual validation run (cleans stale labels first)
make status     # Check node labels and job status
make logs       # Show logs from the most recent run
make teardown   # Remove all resources and clean node labels
make help       # Display available targets
```

## Current Configuration

| Parameter           | Value                                                                                            |
| ------------------- | ------------------------------------------------------------------------------------------------ |
| Workload image      | `docker.io/rocm/roce-workload:ubuntu24_rocm-7.0.2_rccl-7.0.2_anp-v1.2.0_ainic-1.117.5-a-56`    |
| Test-runner image   | `docker.io/rocm/test-runner:v1.5.0`                                                             |
| PF NICs per worker  | 7                                                                                                |
| GPUs per worker     | 8                                                                                                |
| Worker replicas     | 2                                                                                                |
| GPU validation      | Enabled (`SKIP_GPU_VALIDATION: "false"`)                                                         |
| GPU test            | RVS `gst_single` (parallel, 1200s timeout)                                                       |
| CronJob schedule    | Hourly (default)                                                                                 |

### Available Workload Image Tags

| Tag                                                          | ROCm | RCCL  | ANP   | Firmware |
| ------------------------------------------------------------ | ---- | ----- | ----- | -------- |
| `ubuntu24_rocm-7.0.2_rccl-7.0.2_anp-v1.2.0_ainic-1.117.5-a-77` | 7.0.2 | 7.0.2 | v1.2.0 | a-77     |
| `ubuntu24_rocm-7.2_rccl-7.2.0_anp-v1.3.0_ainic-1.117.5-a-56`   | 7.2   | 7.2.0 | v1.3.0 | a-56     |

## Files

| File                              | Purpose                                                                  |
| --------------------------------- | ------------------------------------------------------------------------ |
| `kustomization.yaml`              | Kustomize entrypoint; pulls MPI Operator v0.8.0 and local manifests      |
| `00_nad-amd-rdma.yaml`            | NetworkAttachmentDefinition for the RDMA network                         |
| `cluster-validation-config.yaml`  | ConfigMaps: node selection, RCCL tests, GPU validation, fluentbit config |
| `cluster-validation-job.yaml`     | CronJob definition, MPIJob template, test-runner template, RBAC          |
| `Makefile`                        | deploy / run / teardown / status / logs / help targets                   |
| `results/`                        | Timestamped subdirectories with cronjob and fluentbit logs from manual runs |

## Check Validation Results

```bash
# Node labels
oc get nodes -o custom-columns='NODE:.metadata.name,STATUS:.metadata.labels.amd\.com/cluster-validation-status,CANDIDATE:.metadata.labels.amd\.com/cluster-validation-candidate'

# GPU validation labels
oc describe node | grep "amd.com/gpu-validation-test\|Name:"
```

### Node Label Reference

| Label                                      | Meaning                       |
| ------------------------------------------ | ----------------------------- |
| `amd.com/cluster-validation-status=passed` | Node passed all RCCL tests    |
| `amd.com/cluster-validation-status=failed` | Node failed one or more tests |
| `amd.com/gpu-validation-test=passed`       | Node passed GPU health check  |
| `amd.com/gpu-validation-test=failed`       | Node failed GPU health check  |

## Prerequisites

- AMD Network Operator deployed
- Nodes labeled with `feature.node.kubernetes.io/amd-gpu=true` and `feature.node.kubernetes.io/amd-nic=true`
- **GPUs must be allocatable** (`amd.com/gpu >= 1`) on candidate nodes -- DRA partitioning sets `amd.com/gpu: 0`, which prevents test runner pods from scheduling
- **Full SPX GPUs required** -- the GST performance thresholds assume full SPX GPUs; CPX-partitioned nodes will fail every benchmark

## Configuration Notes

Before deployment, operators may need to customize:

- **Image tags**: Update `RCCL_WORKLOAD_IMAGE` and `TEST_RUNNER_IMAGE` in `cluster-validation-config.yaml`
- **Resource limits**: Ensure `SLOTS_PER_WORKER`, `GPU_PER_WORKER`, and `PF_NIC_PER_WORKER` match the cluster hardware
- **CronJob schedule**: Modify `spec.schedule` in `cluster-validation-job.yaml` to adjust validation frequency
- **GPU validation**: Set `SKIP_GPU_VALIDATION` to `"true"` to skip GPU health checks and go directly to RCCL tests
- **Debug mode**: `DEBUG_DELAY` pauses after job completion for troubleshooting (currently 20s)
- **`NCCL_DMABUF_ENABLE`**: Must be `0` on kernels < 6.x. DMABuf requires kernel 6.x + amdgpu-dkms >= 6.14. RHEL 9.x ships kernel 5.14, so DMABuf is not available -- enabling it causes `local access violation` errors during RCCL tests

## Cleanup

```bash
# Remove all resources
make teardown
```

When re-running validations, stale labels from previous runs can cause issues. The `make run` target handles this automatically.

## Troubleshooting

### RDMA QP connection timeout during multi-node RCCL tests

```log
ibv_modify_qp failed with 110 Connection timed out, on dev ionic_X:0,
curr state INIT, next state RTR, local GID index 1, local GID N/A,
remote GID ::ffff:192.168.200.XX
```

RCCL fails to transition RDMA Queue Pairs from INIT to RTR because the remote GID is unreachable. This means there is no L2 connectivity between the nodes over the RDMA network (`192.168.200.0/24` assigned by whereabouts IPAM).

Common causes:

- **Switch not forwarding traffic** between the NIC ports (VLAN misconfiguration, ports not in the same broadcast domain)
- **Auto-negotiation mismatch** -- NIC ports stuck in `AN_WAIT_HCD` state. Verify with `nicctl list port` and disable AN if the switch does not support it
- **NIC ports DOWN** -- check link state with `ip -br link show` on each node

To verify L2 connectivity independently of the validation framework:

```bash
# On node A
ip addr add 10.99.99.1/24 dev <pensando-iface>
# On node B
ip addr add 10.99.99.2/24 dev <pensando-iface>
arping -c 3 -I <pensando-iface> 10.99.99.1
```

## References

- [MPI Operator Introduction](https://medium.com/kubeflow/introduction-to-kubeflow-mpi-operator-and-industry-adoption-296d5f2e6edc)
- [MPI Operator Documentation](https://www.kubeflow.org/docs/components/trainer/legacy-v1/user-guides/mpi/)
- [MPI Operator GitHub](https://github.com/kubeflow/mpi-operator/blob/master/README.md)
- [AMD GPU Cluster Networking troubleshooting guide](https://instinct.docs.amd.com/projects/gpu-cluster-networking/en/latest/how-to/troubleshooting.html)
- [RVS test recipes](https://instinct.docs.amd.com/projects/gpu-operator/en/latest/test/appendix-test-recipe.html)
