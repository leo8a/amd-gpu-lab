# Two-Node GPUDirect RDMA (GDR) Bandwidth Test

Validates GPU-to-GPU RDMA write bandwidth between two nodes using `ib_write_bw --use_rocm=0` over AMD Pensando Pollara 400 AI NICs. Data flows directly between GPU memory via `ib_peer_mem`, bypassing CPU memory.

For CPU-memory RDMA, see [01_multi-node-cpu](../01_multi-node-cpu/).

## Prerequisites

All [01_multi-node-cpu prerequisites](../01_multi-node-cpu/README.md#prerequisites), plus:

| Requirement       | Details                                                          |
| ----------------- | ---------------------------------------------------------------- |
| `ib_peer_mem`     | Kernel module loaded (`lsmod \| grep ib_peer_mem`)               |
| AMD GPUs          | `amd.com/gpu >= 1` allocatable on each node                      |
| Container image   | ROCm perftest image (`quay.io/lochoa/amd-tools:gdr`)             |

**Verify GDR readiness:**

```bash
# Check ib_peer_mem is loaded
oc debug node/<node> -- chroot /host lsmod | grep ib_peer_mem

# Check GPU allocatable
oc get nodes -o json | jq '.items[] | {name: .metadata.name, gpu: .status.allocatable["amd.com/gpu"]}'
```

## Run

```bash
oc apply -k .
oc logs -n openshift-amd-network rdma-server-gdr
oc logs -n openshift-amd-network -l job-name=rdma-client-gdr
```

Or via the parent Makefile:

```bash
cd .. && make multi-node-gdr
```

## Expected Output

Same flow as the CPU test, but with `--use_rocm=0` to pin buffers in GPU memory. Bandwidth is slightly lower due to `ib_peer_mem` GPU memory registration overhead, but data never touches CPU memory — it flows directly from MI325X VRAM through the Pollara 400 NIC to the remote GPU.

**Results** (2026-06-03, smc6217gpu <-> smc6216gpu, MI325X, Pollara 400, 4 QP, 1M messages, MTU 9000):

| Test             | Data path                        | Bandwidth  |
| ---------------- | -------------------------------- | ---------- |
| `multi-node-cpu` | CPU mem -> NIC -> NIC -> CPU mem | 82.63 Gb/s |
| `multi-node-gdr` | GPU mem -> NIC -> NIC -> GPU mem | 77.25 Gb/s |

> GDR bandwidth is slightly lower than CPU due to `ib_peer_mem` memory registration overhead — each RDMA operation must pin and translate GPU virtual addresses through the PCIe BAR before the NIC can DMA directly to/from VRAM. CPU buffers skip this step since system memory is natively accessible to the NIC.

## Cleanup

```bash
oc delete -k .
```

## Reference

- [AMD Pensando Pollara AI 400G NIC Operations Guide (UG1801)](https://docs.amd.com/r/en-US/ug1801-ai-nic-pollara-400-ops-guide) — QoS, PFC, DCQCN configuration
- [AMD Pollara 400 Benchmarking Guide (UG1813)](https://docs.amd.com/r/en-US/ug1813-pollara-400-benchmarking-guide) — recommended perftest parameters
- [NIC prerequisites](../docs/nic-prereqs.md) — per-port and per-device QoS commands
- [Tuning notes](../docs/tunning-notes.md) — MTU, queue pair, and message size tuning results

## Files

| File                     | Purpose                                         |
| ------------------------ | ----------------------------------------------- |
| `00_nad-amd-rdma.yaml`   | NetworkAttachmentDefinition for RDMA (MTU 9000) |
| `01_serviceaccount.yaml` | ServiceAccount with privileged SCC              |
| `02_rdma-server.yaml`    | RDMA GDR server pod (1 GPU + 1 NIC)             |
| `03_rdma-client.yaml`    | RDMA GDR client job (1 GPU + 1 NIC)             |
