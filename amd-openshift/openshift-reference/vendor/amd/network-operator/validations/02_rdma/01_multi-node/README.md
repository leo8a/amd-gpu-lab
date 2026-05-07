# Two-Node RDMA Connectivity Tests

Tests to validate RDMA network connectivity between two nodes.

## Prerequisites

- RDMA exclusive mode enabled (kernel arg `ib_core.netns_mode=0`)
- AMD Network Operator deployed
- **At least 2 nodes** labeled with `feature.node.kubernetes.io/amd-nic=true`
- **At least 2 AI NICs physically connected** between the nodes (carrier up) — the server and client pods are scheduled on different nodes via anti-affinity, so the RDMA network must have L2 connectivity

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

## Server-Client Pod Test

Interactive test with server and client pods on different nodes.

```bash
oc apply -k .
oc logs -n openshift-amd-network rdma-server
oc logs -n openshift-amd-network rdma-client
```

Expected: Client discovers server and successfully pings over RDMA network.

## Cleanup

```bash
oc delete -k .
```

## Files

- `00_nad-amd-rdma.yaml` - NetworkAttachmentDefinition for RDMA network
- `01_serviceaccount.yaml` - ServiceAccount with privileged SCC
- `02_rdma-server.yaml` - RDMA server pod
- `03_rdma-client.yaml` - RDMA client pod
