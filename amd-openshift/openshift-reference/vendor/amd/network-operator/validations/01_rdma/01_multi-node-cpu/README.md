# Two-Node RDMA Bandwidth Test (CPU Memory)

Validates RDMA write bandwidth between two nodes using `ib_write_bw` over AMD Pensando Pollara 400 AI NICs. Data transfers use **CPU memory** buffers.

For GPU-to-GPU RDMA (GDR), see [02_multi-node-gdr](../02_multi-node-gdr/).

## Prerequisites

| Requirement                  | Details                                                                                                                                                                   |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| AI NIC profile               | `default` (Non-breakout mode 1x400G, no VFs)                                                                                                                              |
| RDMA exclusive mode          | Kernel arg `ib_core.netns_mode=0`                                                                                                                                         |
| AMD Network Operator         | Deployed and running                                                                                                                                                      |
| GPU nodes                    | At least 2 nodes labeled `feature.node.kubernetes.io/amd-nic=true`                                                                                                        |
| Physical connectivity        | At least 2 AI NICs with carrier up between nodes (L2 reachable)                                                                                                           |
| NIC QoS                      | Auto-neg disabled, PFC on priority 3, DSCP mappings, DCQCN per device — see [nic-prereqs.md](../docs/nic-prereqs.md). **Does not persist across reboots.**                |
| Switch PFC                   | Priority 3 enabled, matching the NIC QoS configuration                                                                                                                    |

> [RFE: Declarative NIC configuration CRD for Pollara 400 (auto-neg, PFC, QoS, DCQCN)](https://github.com/ROCm/network-operator/issues/91) — tracks making NIC QoS settings survive reboots.

**Verify NIC link state:**

```bash
oc debug node/<node> -- chroot /host bash -c \
  'for iface in $(ls /sys/class/net/ | grep enp); do
     driver=$(basename $(readlink /sys/class/net/$iface/device/driver) 2>/dev/null)
     [ "$driver" = "ionic" ] && echo "$iface: $(cat /sys/class/net/$iface/operstate)"
   done'
```

> If only 1 node has AMD NICs, pods will run on the same node and won't find each other during network scans.

## Run

```bash
oc apply -k .
oc logs -n openshift-amd-network rdma-server-cpu
oc logs -n openshift-amd-network -l job-name=rdma-client-cpu
```

## Expected Output

The server listens on TCP port 10000 for QP exchange, then runs the RDMA write bandwidth test. The client discovers the server via ICMP scan, connects, and measures write bandwidth.

**Server** (`oc logs -n openshift-amd-network rdma-server-cpu`):

```logs
=== RDMA Server Starting ===
--- waiting for net1 ---
Server IP: 192.168.200.17
--- RDMA device ---
Using: ionic_4
...
--- starting ib_write_bw server on port 10000 ---
                    RDMA_Write Post List BW Test
 Dual-port       : OFF          Device         : ionic_4
 Number of qps   : 8            Transport type : IB
 Connection type : RC
 Post List       : 64
 CQ Moderation   : 1
 ...
 #bytes     #iterations    BW peak[Gb/sec]    BW average[Gb/sec]   MsgRate[Mpps]
 1048576    284278           0.00               397.44               0.047379
```

**Client** (`oc logs -n openshift-amd-network -l job-name=rdma-client-cpu`):

```logs
 #bytes     #iterations    BW peak[Gb/sec]    BW average[Gb/sec]   MsgRate[Mpps]
 1048576    284278           0.00               397.44               0.047379
=== PASS ===
```

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

| File                      | Purpose                              |
| ------------------------- | ------------------------------------ |
| `00_nad-amd-rdma.yaml`    | NetworkAttachmentDefinition for RDMA |
| `01_serviceaccount.yaml`  | ServiceAccount with privileged SCC   |
| `02_rdma-server.yaml`     | RDMA server pod                      |
| `03_rdma-client.yaml`     | RDMA client job                      |
