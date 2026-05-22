# AMD Tools Container Image

RDMA validation tools for AMD Pensando NICs on OpenShift.

## Contents

| Package            | Tools                                        |
| ------------------ | -------------------------------------------- |
| `perftest`         | `ib_write_bw`, `ib_read_bw`, `ib_send_bw`    |
| `libibverbs-utils` | `ibv_devinfo`, `ibv_devices`                 |
| `rdma-core`        | Core RDMA libraries                          |
| `iproute`          | `ip`, `ss`                                   |
| `iputils`          | `ping`                                       |

## Build and Push

```bash
podman build -t quay.io/lochoa/amd-tools:latest -f Containerfile .
podman push quay.io/lochoa/amd-tools:latest
```
