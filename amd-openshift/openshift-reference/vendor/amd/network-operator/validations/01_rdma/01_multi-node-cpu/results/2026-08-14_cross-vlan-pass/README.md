# 2026-08-14 — Cross-VLAN CPU-to-CPU RDMA (PASS)

| Parameter       | Value                                       |
| --------------- | ------------------------------------------- |
| Test            | ib_write_bw (CPU-to-CPU, 1 NIC per pod)     |
| Server          | smc6216gpu / ionic_0 / VLAN 101             |
| Client          | smc6217gpu / ionic_5 / VLAN 106             |
| NIC config      | PFC prio 3, DSCP 24/46, DCQCN enabled       |
| Message size    | 1 MB                                        |
| QPs             | 8                                           |
| Duration        | 10s                                         |
| Kernel          | 5.14.0-570.122.1.el9_6.x86_64               |

## Results

| Metric             | Value      |
| ------------------ | ---------- |
| BW average (Gb/s)  | 397.44     |
| MsgRate (Mpps)     | 0.047378   |

Server and client landed on different VLANs (101 vs 106). Cross-VLAN routing via switch SVIs + pod-side routes to gateway (.254) enabled the RDMA data path.
