# Some tunning notes

---

## MTU tunning

● The NAD tuning plugin works:

  ┌───────────────────┬──────────────────┐
  │ Before (MTU 1500) │ After (MTU 9000) │
  ├───────────────────┼──────────────────┤
  │ active_mtu: 1024  │ active_mtu: 4096 │
  ├───────────────────┼──────────────────┤
  │ IB Mtu: 1024 B    │ IB Mtu: 4096 B   │
  ├───────────────────┼──────────────────┤
  │ 7.92 Gb/s         │ 33.66 Gb/s       │
  └───────────────────┴──────────────────┘

-> 4x bandwidth improvement just from the MTU change. The RDMA device picked up the 9K MTU from the tuning plugin automatically. Line rate (400 Gb/s) would require switch PFC tuning and possibly multi-QP configurations, but 33.66 Gb/s on a single QP with default settings is solid.

-> Yes — the MTU can be configured directly via the NAD using the tuning CNI plugin. No MachineConfig needed. The active_mtu jumped from 1024 to 4096 (the max IB MTU for RoCEv2 over 9K Ethernet), and bandwidth went from 7.92 to 33.66 Gb/s.

---

## Queue pairs and message size

● Increasing queue pairs (`-q`) and message size (`-s`) per the AMD Benchmarking Guide (UG1813):

  ┌──────────────────────────┬───────────┐
  │ Config                   │ BW avg    │
  ├──────────────────────────┼───────────┤
  │ 1 QP, 64K msg, MTU 1500  │ 7.92 Gb/s │
  ├──────────────────────────┼───────────┤
  │ 1 QP, 64K msg, MTU 9000  │ 33.66 Gb/s│
  ├──────────────────────────┼───────────┤
  │ 4 QP, 1M msg, MTU 9000   │ 81.95 Gb/s│
  └──────────────────────────┴───────────┘

-> 10x total improvement from baseline. `-q 4` saturates the NIC pipeline, `-s 1M` reduces per-message overhead. Remaining gap to 400G line rate requires switch-side PFC tuning and end-to-end congestion management.

---

## Switch PFC (not yet applied)

● The switch between nodes must have PFC enabled on the same priority queues as the NICs. Without end-to-end PFC, the switch drops RoCEv2 packets under load and DCQCN throttles the sender — capping throughput at ~20% of line rate.

Required switch config (must match NIC QoS):

- PFC enabled on priority 3 (no-drop for RoCEv2 data, DSCP 24)
- ECN/WRED thresholds for congestion marking
- SPQ on priority 6 with 10G rate-limit (CNP packets, DSCP 46)
- DWRR scheduling: 99% Q3 (RDMA), 1% Q0 (default)

-> Reference configs for Cisco Nexus, Juniper QX, Arista, and Micas switches are in the AMD Ops Guide (UG1801, p.91-93).
