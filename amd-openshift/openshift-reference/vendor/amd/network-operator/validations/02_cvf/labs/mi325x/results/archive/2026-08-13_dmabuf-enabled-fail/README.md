# 2026-08-13 — 8 GPU / 7 NIC, DMABUF enabled (FAIL)

| Parameter       | Value                                              |
| --------------- | -------------------------------------------------- |
| GPUs (MPI NP)   | 16 (8 per node)                                    |
| NICs            | 7 (ionic_0 – ionic_6)                              |
| ANP plugin      | yes                                                |
| DMABUF          | enabled (NCCL_DMABUF_ENABLE=1)                     |
| Nodes           | smc6216gpu, smc6217gpu                             |
| Kernel          | 5.14.0-570.122.1.el9_6.x86_64                      |
| ROCm            | 7.0.2 (ROCr 1.18)                                  |
| Failure reason  | SIGSEGV (null pointer) in RCCL DMABUF init path    |
