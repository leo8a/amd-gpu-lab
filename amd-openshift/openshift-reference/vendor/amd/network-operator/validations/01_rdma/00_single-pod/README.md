# Single Pod RDMA Device Test

Validates NIC attachment, RDMA device visibility, and link speed on a single pod using host-device CNI.

## Prerequisites

- AMD Network Operator deployed
- Nodes labeled with `feature.node.kubernetes.io/amd-nic=true`

## Run Test

```bash
make single-pod       # from parent directory
# or
oc apply -k .
```

## Expected Output

- All RDMA devices on the node visible under `/sys/class/infiniband` (e.g. `ionic_0`–`ionic_6` plus any non-AMD devices like `mlx5_0`)
- Device type: `1: CA` (Channel Adapter)
- RDMA network interface: `net1` with IP from 192.168.200.0/24

```logs
=== RDMA Single-Pod Validation ===
--- interfaces ---
lo               UNKNOWN        00:00:00:00:00:00 <LOOPBACK,UP,LOWER_UP>
eth0@if964       UP             0a:58:0a:80:00:c0 <BROADCAST,MULTICAST,UP,LOWER_UP>
net1             UP             04:90:81:36:72:a8 <BROADCAST,MULTICAST,UP,LOWER_UP>
--- RDMA devices ---
ionic_0: type=1: CA guid=0690:81ff:fe36:72a8
ionic_1: type=1: CA guid=0690:81ff:fe36:7d70
ionic_2: type=1: CA guid=0690:81ff:fe36:a758
ionic_3: type=1: CA guid=0690:81ff:fe36:6cc0
ionic_4: type=1: CA guid=0690:81ff:fe36:6c18
ionic_5: type=1: CA guid=0690:81ff:fe36:9e28
ionic_6: type=1: CA guid=0690:81ff:fe36:8178
mlx5_0: type=1: CA guid=5000:e603:00a9:7668
--- secondary NIC details ---
653: net1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP group default qlen 1000
    link/ether 04:90:81:36:72:a8 brd ff:ff:ff:ff:ff:ff
    inet 192.168.200.15/24 brd 192.168.200.255 scope global net1
--- link speed ---
net1: 400000 Mbps
=== PASS ===
```

## Cleanup

```bash
oc delete -k .
```

## Files

- `00_nad-amd-rdma.yaml` - NetworkAttachmentDefinition for RDMA network
- `01_single-pod-test.yaml` - Single pod RDMA device and NIC validation job
