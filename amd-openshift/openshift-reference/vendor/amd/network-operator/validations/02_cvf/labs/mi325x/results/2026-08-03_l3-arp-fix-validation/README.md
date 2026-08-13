# 2026-08-03 — 8 GPU / 7 NIC, L3 ARP fix (PASS)

| Parameter       | Value                    |
| --------------- | ------------------------ |
| GPUs (MPI NP)   | 16 (8 per node)          |
| NICs            | 7 (ionic_0 – ionic_6)    |
| ANP plugin      | yes                      |
| DMABUF          | disabled                 |
| Nodes           | smc6216gpu, smc6217gpu   |

## Results (Gb/s)

| Test                | Actual | Threshold |
| ------------------- | ------ | --------- |
| all_reduce_perf     | 72.40  | > 5       |
| broadcast_perf      | 57.57  | > 5       |
| reduce_scatter_perf | 76.65  | > 5       |
