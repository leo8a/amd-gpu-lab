# Two-Node GPUDirect RDMA (GDR) Bandwidth Test

Validates GPU-to-GPU RDMA write bandwidth between two nodes using `ib_write_bw --use_rocm=0` over Pollara 400 AI NICs. Data flows directly between GPU memory via `ib_peer_mem`, bypassing CPU memory.

## Prerequisites

All [01_multi-node prerequisites](../01_multi-node/README.md#prerequisites), plus:

- `ib_peer_mem` kernel module loaded (`lsmod | grep ib_peer_mem`)
- AMD GPUs allocatable (`amd.com/gpu >= 1` on each node)
- Container image built with ROCm perftest (`quay.io/lochoa/amd-tools:gdr`)

**Verify GDR readiness:**

```bash
# Check ib_peer_mem is loaded and used by ionic_rdma
oc debug node/<node> -- chroot /host lsmod | grep ib_peer_mem

# Check GPU allocatable
oc get nodes -o json | jq '.items[] | {name: .metadata.name, gpu: .status.allocatable["amd.com/gpu"]}'
```

## Run

```bash
oc apply -k .
oc logs -n openshift-amd-network rdma-server
oc logs -n openshift-amd-network -l job-name=rdma-client
```

Or via the parent Makefile:

```bash
cd .. && make multi-node-gdr
```

## Cleanup

```bash
oc delete -k .
```

## Results (2026-06-03)

Tested on smc6217gpu ↔ smc6216gpu (MI325X, Pollara 400, 4 QP, 1M messages, MTU 9000):

| Test             | Data path                              | Bandwidth    |
| ---------------- | -------------------------------------- | ------------ |
| `multi-node-cpu` | CPU mem → NIC → NIC → CPU mem          | 82.63 Gb/s   |
| `multi-node-gdr` | GPU mem → NIC → NIC → GPU mem          | 77.25 Gb/s   |

GDR is slightly lower due to `ib_peer_mem` GPU memory registration overhead, but data never touches CPU memory — it flows directly from MI325X VRAM through the Pollara 400 NIC to the remote GPU.

## Files

- `00_nad-amd-rdma.yaml` - NetworkAttachmentDefinition for RDMA network (MTU 9000)
- `01_serviceaccount.yaml` - ServiceAccount with privileged SCC
- `02_rdma-server.yaml` - RDMA GDR server pod (requests 1 GPU + 1 NIC)
- `03_rdma-client.yaml` - RDMA GDR client job (requests 1 GPU + 1 NIC)
