# 2026-08-14 — DRA NIC-Pinned CPU-to-CPU RDMA (PASS)

| Parameter       | Value                                          |
| --------------- | ---------------------------------------------- |
| Test            | ib_write_bw (CPU-to-CPU, DRA NIC pinning)      |
| Server          | smc6216gpu / ionic_0 / 0000:09:00.0 / VLAN 101 |
| Client          | smc6217gpu / ionic_0 / 0000:09:00.0 / VLAN 101 |
| NIC selection   | DRA CEL selector: pciAddress == '0000:09:00.0' |
| NIC config      | PFC prio 3, DSCP 24/46, DCQCN enabled          |
| Message size    | 1 MB                                           |
| QPs             | 8                                              |
| Duration        | 10s                                            |
| Kernel          | 5.14.0-570.122.1.el9_6.x86_64                  |

## Results

| Metric             | Value      |
| ------------------ | ---------- |
| BW average (Gb/s)  | 397.44     |
| MsgRate (Mpps)     | 0.047378   |

## Key observations

- DRA (DRANET driver) successfully pinned ionic_0 on both nodes via `device.attributes['dra.net'].pciAddress == '0000:09:00.0'`
- Both pods on same VLAN (101) — no cross-VLAN routing needed
- Same bandwidth as device-plugin approach (397.43-397.45 Gb/s), confirming no DRA overhead
- No NAD or Multus required — NIC accessed directly through DRA resourceClaim
