# DRA Validation Limitations

---

## rocm-smi cannot detect GPU partitions allocated via DRA

`rocm-smi` reports "No AMD GPUs specified" inside DRA containers running on partitioned GPUs (CPX/NPS4), even though the devices are correctly injected.

### What happens

The CDI spec mounts the correct device nodes into the container:

```logs
/dev/dri/card36       226, 36    (present)
/dev/dri/renderD163   226, 163   (present)
/dev/kfd              510, 0     (present)
```

But `rocm-smi` enumerates GPUs by scanning `/dev/dri/renderD*` and looking up PCI vendor attributes in sysfs (`/sys/class/drm/renderDN/device/vendor`). It expects `0x1002` (AMD).

### Why it fails

In CPX mode, each physical GPU is split into 8 XCP (eXtensible Compute Partition) partitions. Only the **first** partition per GPU gets a PCI-backed sysfs path:

| Partition     | sysfs path                                                | rocm-smi |
| ------------- | --------------------------------------------------------- | -------- |
| 1st (PCI)     | `/sys/devices/pci0000:e0/.../0000:e5:00.0/drm/renderD176` | Works    |
| 2nd-8th (XCP) | `/sys/devices/platform/amdgpu_xcp_N/drm/renderDN`         | Fails    |

XCP platform devices lack PCI attributes (`vendor`, `device`, `product_name`), so `rocm-smi` does not recognize them as AMD GPUs. On an 8-GPU node with CPX/NPS4, 8 out of 64 partitions are PCI-backed (12.5%) -- the test appears to pass intermittently depending on which partition the scheduler picks.

### What works instead

`clinfo` (OpenCL) and `rocminfo` (HSA) both discover GPU partitions correctly via XCP devices:

```logs
$ clinfo | grep -E '(Number of devices|Board name|Max compute units|Global memory size)'
Number of devices:    1
  Board name:         AMD Instinct MI325X
  Max compute units:  38               # CPX = 304 CUs / 8
  Global memory size: 34359738368      # NPS4 = 256G / 8

$ rocminfo | grep -E '(Device Type:.*GPU|Compute Unit:)'
  Device Type:        GPU
  Compute Unit:       38
```

The DRA validation tests use `clinfo` for partition detection instead of `rocm-smi`.

### Upstream tracking

- `ROCm/k8s-gpu-dra-driver` -- CDI specs generate `DeviceNodes` only, no sysfs mounts
- `rocm-smi` / amdgpu kernel driver -- GPU discovery assumes PCI-backed devices, does not support XCP platform devices
