# AMD Cluster Validation Framework (CVF)

Validates GPU health (RVS `gst_single`) and multi-node RDMA/RCCL performance (`all_reduce_perf`, `broadcast_perf`, `reduce_scatter_perf`) on OpenShift.

Based on the [AMD Network Operator Cluster Validation Framework](https://instinct.docs.amd.com/projects/network-operator/en/latest/cluster_validation_framework/README.html).

## What It Does

1. Deploys Kubeflow MPI Operator (v0.8.0) for distributed job execution
2. Creates ConfigMaps for config, MPIJob template, test-runner template, and fluentbit
3. Deploys a CronJob with `submit-mpijob` and `fluent-bit` containers
4. Runs GPU health checks (RVS) on each candidate node, then multi-node RCCL benchmarks via MPIJobs
5. Applies node labels based on validation results

## Lab Structure

Lab-specific manifests live under `labs/`. Toggle the active lab by commenting/uncommenting resource lines in `kustomization.yaml`.

```tree
02_cvf/
  kustomization.yaml           # toggle between labs
  labs/
    mi325x/                    # Supermicro SMC6217/6216 (AMD MI325X lab)
    mi355x/                    # Dell XE9785L (RH MI355X lab)
  patches/                     # shared patches
  Makefile                     # deploy / run / teardown / status / logs
```

### MI325X Lab (Supermicro SMC6217/6216)

| Parameter          | Value                                                                                         |
| ------------------ | --------------------------------------------------------------------------------------------- |
| Nodes              | smc6217gpu, smc6216gpu                                                                        |
| NICs per node      | 7 Pensando DSC3 (400G)                                                                        |
| PF NICs per worker | 7                                                                                             |
| VLANs              | 101–107 (one per NIC pair)                                                                    |
| GPUs per worker    | 8                                                                                             |
| Worker replicas    | 2                                                                                             |
| Results            | `labs/mi325x/results/`                                                                        |

### MI355X Lab (Dell XE9785L)

| Parameter          | Value                                                                                         |
| ------------------ | --------------------------------------------------------------------------------------------- |
| Nodes              | dell-mi355x-3, dell-mi355x-4                                                                  |
| NICs per node      | 8 Pensando DSC3 (400G) — 4 on NUMA 0, 4 on NUMA 1                                             |
| PF NICs per worker | 8                                                                                             |
| VLANs              | 101–108 (one per NIC pair)                                                                    |
| GPUs per worker    | 8                                                                                             |
| Worker replicas    | 2                                                                                             |

### Available Workload Image Tags

| Tag                                                              | ROCm  | RCCL  | ANP    | Firmware |
| ---------------------------------------------------------------- | ----- | ----- | ------ | -------- |
| `ubuntu24_rocm-7.0.2_rccl-7.0.2_anp-v1.2.0_ainic-1.117.5-a-77`   | 7.0.2 | 7.0.2 | v1.2.0 | a-77     |
| `ubuntu24_rocm-7.2_rccl-7.2.0_anp-v1.3.0_ainic-1.117.5-a-56`     | 7.2   | 7.2.0 | v1.3.0 | a-56     |

## Quick Start

```bash
make deploy     # Deploy MPI Operator, CronJob, ConfigMaps
make run        # Trigger a manual validation run (cleans stale labels first)
make status     # Check node labels and job status
make logs       # Show logs from the most recent run
make teardown   # Remove all resources and clean node labels
make help       # Display available targets
```

## Files

| File                                        | Purpose                                                                  |
| ------------------------------------------- | ------------------------------------------------------------------------ |
| `kustomization.yaml`                        | Kustomize entrypoint; pulls MPI Operator v0.8.0 and lab-specific files   |
| `labs/<lab>/00_nad-amd-rdma.yaml`           | Per-VLAN NADs for L3-routed multi-NIC RoCE                               |
| `labs/<lab>/cluster-validation-config.yaml` | ConfigMaps: node selection, RCCL tests, GPU validation, fluentbit        |
| `labs/<lab>/cluster-validation-job.yaml`    | CronJob, MPIJob template (with init container PCI→subnet mapping), RBAC  |
| `Makefile`                                  | deploy / run / teardown / status / logs / help targets                   |

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

### Switch prerequisites

Each NIC pair across nodes needs its own VLAN to avoid ARP flux (see [issue #7](../../../docs/found-issues.md#7-arp-flux-on-flat-l2-breaks-multi-nic-rccl--cqe-error-12-on-3-nics)). Configure one VLAN per NIC pair on the backend switch:

| Lab    | VLANs   | Subnets                     |
| ------ | ------- | --------------------------- |
| MI325X | 101–107 | `192.168.101.0/24` – `.107` |
| MI355X | 101–108 | `192.168.101.0/24` – `.108` |

Per VLAN:

- 2 untagged ports (one per server, matching the NIC's physical cable)
- SVI gateway at `192.168.<vlan>.254/24`
- Proxy ARP enabled

## Configuration Notes

Before deployment, customize the active lab's files under `labs/<lab>/`:

- **Image tags**: Update `RCCL_WORKLOAD_IMAGE` and `TEST_RUNNER_IMAGE` in `cluster-validation-config.yaml`
- **Resource limits**: Ensure `SLOTS_PER_WORKER`, `GPU_PER_WORKER`, and `PF_NIC_PER_WORKER` match the cluster hardware
- **PCI→subnet mapping**: Update the `nic-routing-setup` init container in `cluster-validation-job.yaml` with the correct PCI BDFs and node hostnames for the target lab
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

- **[RoCE cluster network configuration guide](https://instinct.docs.amd.com/projects/cluster-documentation/latest/how-to/roce-network-config.html#roce-configuration-for-network-switches)** -- switch and NAD configuration for multi-NIC RoCE (L3 routed with /31 subnets to avoid ARP flux)
- [MPI Operator Introduction](https://medium.com/kubeflow/introduction-to-kubeflow-mpi-operator-and-industry-adoption-296d5f2e6edc)
- [MPI Operator Documentation](https://www.kubeflow.org/docs/components/trainer/legacy-v1/user-guides/mpi/)
- [MPI Operator GitHub](https://github.com/kubeflow/mpi-operator/blob/master/README.md)
- [AMD GPU Cluster Networking troubleshooting guide](https://instinct.docs.amd.com/projects/gpu-cluster-networking/en/latest/how-to/troubleshooting.html)
- [RVS test recipes](https://instinct.docs.amd.com/projects/gpu-operator/en/latest/test/appendix-test-recipe.html)
