# 2026-07-22 — 2 GPU / 1 NIC (PASS)

| Parameter       | Value                  |
| --------------- | ---------------------- |
| GPUs (MPI NP)   | 4 (2 per node)         |
| NICs            | 1 (ionic_0)            |
| ANP plugin      | yes                    |
| DMABUF          | disabled               |
| Nodes           | smc6216gpu, smc6217gpu |

## Results (Gb/s)

| Test                | Actual | Threshold |
| ------------------- | ------ | --------- |
| all_reduce_perf     | 13.34  | > 5       |
| broadcast_perf      | 15.72  | > 5       |
| reduce_scatter_perf | 12.47  | > 5       |
