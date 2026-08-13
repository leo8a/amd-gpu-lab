# 2026-07-22 — 8 GPU / 2 NIC (FAIL)

| Parameter       | Value                           |
| --------------- | ------------------------------- |
| GPUs (MPI NP)   | 16 (8 per node)                 |
| NICs            | 2 (ionic_0, ionic_1)            |
| ANP plugin      | yes                             |
| DMABUF          | disabled                        |
| Nodes           | smc6216gpu, smc6217gpu          |
| Failure reason  | 2-NIC QP exhaustion workaround  |
