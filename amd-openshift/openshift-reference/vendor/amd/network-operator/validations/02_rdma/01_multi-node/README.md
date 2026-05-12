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

### Expected Output

Server gets an IP from the RDMA subnet and lists all infiniband devices on the node.
Client discovers the server via ICMP scan and pings it over the RDMA network with 0% packet loss.

`oc logs -n openshift-amd-network rdma-server` (smc6217gpu):

```logs
=== RDMA Server Starting ===
Waiting for RDMA network interface...
Server ready on RDMA network: 192.168.200.2
Listening for ICMP pings on 192.168.200.2...
RDMA device check:
ionic_0
ionic_1
ionic_2
ionic_3
ionic_4
ionic_5
ionic_6
mlx5_0
```

`oc logs -n openshift-amd-network rdma-client` (smc6216gpu):

```logs
=== RDMA Client Starting ===
Waiting for RDMA network interface...
Client ready on RDMA network: 192.168.200.1
Waiting for server to be ready...
Scanning for server on RDMA network...
Scan attempt 1/5...
Found server at: 192.168.200.2

=== Testing RDMA Connectivity ===
PING 192.168.200.2 (192.168.200.2): 56 data bytes
64 bytes from 192.168.200.2: seq=0 ttl=64 time=0.088 ms
64 bytes from 192.168.200.2: seq=1 ttl=64 time=0.092 ms
64 bytes from 192.168.200.2: seq=2 ttl=64 time=0.108 ms
64 bytes from 192.168.200.2: seq=3 ttl=64 time=0.092 ms
64 bytes from 192.168.200.2: seq=4 ttl=64 time=0.090 ms

--- 192.168.200.2 ping statistics ---
5 packets transmitted, 5 packets received, 0% packet loss
round-trip min/avg/max = 0.088/0.094/0.108 ms

=== RDMA Connectivity Test: PASSED ===
Client: 192.168.200.1 -> Server: 192.168.200.2
```

## Cleanup

```bash
oc delete -k .
```

## Files

- `00_nad-amd-rdma.yaml` - NetworkAttachmentDefinition for RDMA network
- `01_serviceaccount.yaml` - ServiceAccount with privileged SCC
- `02_rdma-server.yaml` - RDMA server pod
- `03_rdma-client.yaml` - RDMA client pod
