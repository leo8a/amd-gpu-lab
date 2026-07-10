# Two-Node GPUDirect RDMA (GDR) Bandwidth Test

Validates GPU-to-GPU RDMA write bandwidth between two nodes using `ib_write_bw --use_rocm=0` over AMD Pensando Pollara 400 AI NICs. Data flows directly between GPU VRAM via large BAR memory mapping — the NIC DMA's to/from GPU VRAM through the 256 GB PCIe BAR0, bypassing CPU memory entirely without requiring `ib_peer_mem` or DMABUF.

For CPU-memory RDMA, see [01_multi-node-cpu](../01_multi-node-cpu/).

## Prerequisites

All [01_multi-node-cpu prerequisites](../01_multi-node-cpu/README.md#prerequisites), plus:

| Requirement       | Details                                                          |
| ----------------- | ---------------------------------------------------------------- |
| Large BAR         | GPU BAR0 must expose full VRAM (256 GB on MI325X)                |
| AMD GPUs          | `amd.com/gpu >= 1` allocatable on each node                      |
| Container image   | ROCm perftest image (`quay.io/lochoa/amd-tools:gdr`)             |

**Verify GDR readiness:**

```bash
# Check GPU BAR0 covers full VRAM (should show 256G for MI325X)
oc debug node/<node> -- chroot /host lspci -d 1002: -v | grep -E "Region 0.*prefetchable"

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

Same flow as the CPU test, but with `--use_rocm=0` to pin buffers in GPU VRAM. The MI325X exposes its full 256 GB VRAM via a large PCIe BAR0, so `ibv_reg_mr()` pins GPU memory directly through `pin_user_pages()` — no `ib_peer_mem` or DMABUF required. The NIC DMA's directly from MI325X VRAM through the Pollara 400 NIC to the remote GPU.

**Results** (smc6217gpu <-> smc6216gpu, MI325X, Pollara 400, 8 QP, 1M messages, MTU 9000, post_list 64, tx-depth 4096, GDR pods at 4 CPU / 1Gi Guaranteed QoS):

| Test             | Data path                        | Bandwidth   |
| ---------------- | -------------------------------- | ----------- |
| `multi-node-cpu` | CPU mem -> NIC -> NIC -> CPU mem | 397.42 Gb/s |
| `multi-node-gdr` | GPU mem -> NIC -> NIC -> GPU mem | 391.55 Gb/s |

> GDR bandwidth is slightly lower than CPU because the NIC must DMA across the PCIe fabric to reach GPU VRAM through BAR0, whereas CPU buffers sit in system memory that is natively local to the NIC's PCIe root complex.
>
> GDR bandwidth also varies between runs (observed range: 325-391 Gb/s) due to NUMA topology randomness — no Topology Manager is configured, so the GPU and NIC assigned to the pod may land on different NUMA nodes. When GPU and NIC are on the same NUMA node, GDR reaches ~391 Gb/s (98% line rate); when they cross NUMA, it drops to ~325-360 Gb/s. Enabling `topologyManagerPolicy: single-numa-node` via a PerformanceProfile would eliminate this variance.

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
