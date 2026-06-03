# Two-Node RDMA Bandwidth Test (CPU Memory)

Validates RDMA write bandwidth between two nodes using `ib_write_bw` over Pollara 400 AI NICs. Data transfers use **CPU memory** buffers. For GPU-to-GPU RDMA (GDR), see [02_multi-node-gdr](../02_multi-node-gdr/).

## Prerequisites

- RDMA exclusive mode enabled (kernel arg `ib_core.netns_mode=0`)
- AMD Network Operator deployed
- **At least 2 nodes** labeled with `feature.node.kubernetes.io/amd-nic=true`
- **At least 2 AI NICs physically connected** between the nodes (carrier up) — the server and client pods are scheduled on different nodes via anti-affinity, so the RDMA network must have L2 connectivity
- NIC prerequisites applied (see [docs/nic-prereqs.md](docs/nic-prereqs.md))

**Verify NIC link state:**

```bash
# Check which Pollara NICs have carrier (link) on each node
oc debug node/<node-name> -- chroot /host bash -c \
  'for iface in $(ls /sys/class/net/ | grep enp); do
     driver=$(basename $(readlink /sys/class/net/$iface/device/driver) 2>/dev/null)
     if [ "$driver" = "ionic" ]; then
       echo "$iface: operstate=$(cat /sys/class/net/$iface/operstate) carrier=$(cat /sys/class/net/$iface/carrier 2>/dev/null || echo unknown)";
     fi
   done'
```

> **Note**: If only 1 node has AMD NICs, pods will run on the same node and won't find each other during network scans (expected behavior).

## Run

```bash
oc apply -k .
oc logs -n openshift-amd-network rdma-server
oc logs -n openshift-amd-network -l job-name=rdma-client
```

## Expected Output

Server listens on TCP port 10000 for QP exchange, then runs the RDMA write bandwidth test.
Client discovers the server via ICMP scan, connects for QP exchange, and measures write bandwidth.

`oc logs -n openshift-amd-network rdma-server`:

```logs
=== RDMA Server Starting ===
--- waiting for net1 ---
Server IP: 192.168.200.15
--- RDMA device ---
Using: ionic_3
...
--- starting ib_write_bw server on port 10000 ---
                    RDMA_Write BW Test
 Dual-port       : OFF          Device         : ionic_3
 Number of qps   : 1            Transport type : IB
 Connection type : RC
 ...
 #bytes     #iterations    BW peak[Gb/sec]    BW average[Gb/sec]   MsgRate[Mpps]
 65536      533970           93.32              93.32               0.177989
```

`oc logs -n openshift-amd-network -l job-name=rdma-client`:

```logs
=== RDMA Multi-Node Bandwidth Validation ===
--- waiting for net1 ---
Client IP: 192.168.200.16
--- RDMA device ---
Using: ionic_5
...
--- ib_write_bw test ---
Client: 192.168.200.16 -> Server: 192.168.200.15 (device: ionic_5)
                    RDMA_Write BW Test
 ...
 #bytes     #iterations    BW peak[Gb/sec]    BW average[Gb/sec]   MsgRate[Mpps]
 65536      533970           93.32              93.32               0.177989

=== PASS ===
```

## Cleanup

```bash
oc delete -k .
```

## Files

- `00_nad-amd-rdma.yaml` - NetworkAttachmentDefinition for RDMA network
- `01_serviceaccount.yaml` - ServiceAccount with privileged SCC
- `02_rdma-server.yaml` - RDMA server pod
- `03_rdma-client.yaml` - RDMA client job
- `docs/nic-prereqs.md` - NIC configuration prerequisites for ib_write_bw
