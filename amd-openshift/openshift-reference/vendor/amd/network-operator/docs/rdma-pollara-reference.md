# RDMA on AMD Pensando Pollara 400 AI NICs — Reference Guide

Comprehensive reference for running RDMA with Pollara AI NICs, compiled from AMD official documentation, validated designs, and community resources.

Last updated: 2026-05-12

---

## Documentation Inventory

### AMD Official Documentation

| Doc ID   | Title                                                              | Key RDMA Topics                                                                                         | Link                                                                                                                                                       |
| -------- | ------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| UG1801   | AI NIC Pollara 400 Adapter Operations & Troubleshooting Guide      | QoS/DCQCN/PFC, SR-IOV, RDMA timestamping, GDR (peermem & DMABUF), profiles, personas, RCCL/ANP         | [docs.amd.com](https://docs.amd.com/r/en-US/ug1801-ai-nic-pollara-400-ops-guide)                                                                          |
| UG1717   | Pensando Pollara 400 Operations Guide (combined edition)           | Same as UG1801, consolidated with UG1779/UG1802                                                         | [docs.amd.com](https://docs.amd.com/r/en-US/AMD-Pensando-Pollara-400-Operations-and-Troubleshooting-User-Guide-UG1717-UG1717-UG1779-UG1802-UG1801)         |
| UG1716   | Pensando POLLARA Series Installation Guide                         | Driver install, firmware update, host software setup                                                    | Available via [pensandosupport.amd.com](https://pensandosupport.amd.com)                                                                                  |
| -        | AMD Instinct Customer Acceptance Guide - NIC Installation          | `niccli_rdma_config.sh`, `niccli_ro_config.sh`, `niccli_speedmask.sh`, PFC/DCQCN requirements          | [instinct.docs.amd.com](https://instinct.docs.amd.com/projects/system-acceptance/en/latest/network/nic-installation.html)                                  |
| -        | ROCm Docs - SGLang Distributed Inference with MoRI                 | Most detailed DCQCN/QoS recipe: exact `nicctl` commands, DSCP mappings, PFC, scheduling, fan tuning     | [rocm.docs.amd.com](https://rocm.docs.amd.com/en/latest/how-to/rocm-for-ai/inference/benchmark-docker/sglang-mori-distributed.html)                        |
| -        | UG1801 - RCCL and ANP Installation and Configuration               | RCCL env vars, ANP plugin, NCCL_IB_GID_INDEX, GDR settings, MPI config                                 | [docs.amd.com](https://docs.amd.com/r/en-US/ug1801-ai-nic-pollara-400-ops-guide/RCCL-and-ANP-Installation-and-Configuration)                               |
| -        | UG1801 - GDR using DMABUF                                          | GPU Direct RDMA via DMABUF and peermem, `ib_peer_mem` module, PCIe slot config                          | [docs.amd.com](https://docs.amd.com/r/en-US/ug1801-ai-nic-pollara-400-ops-guide/GDR-using-DMABUF)                                                         |
| -        | UG1801 - SR-IOV on AI NIC                                          | VF creation, profiles (pf1_vf1, hnic_pf1_vf8), VLAN/MAC/Trust/Spoof, ATS for VMs                       | [docs.amd.com](https://docs.amd.com/r/en-US/ug1801-ai-nic-pollara-400-ops-guide/SR-IOV-on-AI-NIC)                                                         |
| -        | AMD Network Operator Cluster Validation Framework                  | MPI-based RCCL benchmarks, node labeling, health checks                                                 | [instinct.docs.amd.com](https://instinct.docs.amd.com/projects/network-operator/en/latest/cluster_validation_framework/README.html)                        |

### Validated Designs & Integration Guides

| Source               | Key Content                                                                   | Link                                                                                                                            |
| -------------------- | ----------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Supermicro + AMD     | MI325X + Pollara RoCEv2 config, 16-1024 node scaling, full cluster recipe     | [supermicro.com (PDF)](https://www.supermicro.com/solutions/validated-design/AMD-Instinct-MI325X-Pensando-Pollara-GPU-Cluster.pdf) |
| Juniper JVD          | DCQCN/PFC on Pollara, GPU-NIC mapping, switch QoS, firmware 1.110.0-a-79     | [juniper.net](https://www.juniper.net/documentation/us/en/software/jvd/jvd-ai-dc-apstra-amd/amd_configuration.html)             |
| AMD Network Operator | Kubernetes operator for NIC driver, device plugin, RDMA/RoCE, metrics         | [rocm.blogs.amd.com](https://rocm.blogs.amd.com/software-tools-optimization/amd-network-operator/README.html)                   |
| ROCm MORI Framework  | Modular RDMA Interface with Pollara support (Dec 2025), GDR + GPU integration | [github.com/ROCm/mori](https://github.com/ROCm/mori)                                                                           |
| Red Hat OCP 4.19     | RDMA CNI for SR-IOV (Mellanox-focused but architecturally relevant)           | [docs.redhat.com](https://docs.redhat.com/en/documentation/openshift_container_platform/4.19/html/hardware_networks/configuring-sriov-rdma-cni) |
| RDMA CNI Plugin      | k8snetworkplumbingwg RDMA CNI for containerized workloads                     | [github.com](https://github.com/k8snetworkplumbingwg/rdma-cni)                                                                 |

### Additional Resources (registration may be required)

- **AMD Pensando Customer Portal**: [pensandosupport.amd.com](https://pensandosupport.amd.com) — firmware bundles, private RCCL/ANP builds
- **Pollara Registration Page**: [account.amd.com](https://account.amd.com/en/forms/registration/tip/tip-pollara-pulsar.html) — access to full docs
- **AI NIC Personas Guide**: [docs.amd.com](https://docs.amd.com/r/en-US/ug1717-ai-nic-pollara-400-user-guide/AI-NICPersonas) — persistent NIC config surviving reboots

---

## RDMA Configuration Layers

Running RDMA on Pollara involves four layers, each with specific configuration requirements.

### Layer 1: NIC Firmware & Driver

| Setting             | Command / Config                                          | Persistence          |
| ------------------- | --------------------------------------------------------- | -------------------- |
| Firmware version    | `nicctl update firmware -i ainic_fw_salina.tar`           | Persistent           |
| Driver version      | Out-of-tree `ionic` driver (min `1.117.5-a-28` for RDMA) | Reinstall on upgrade |
| Blacklist inbox     | `modprobe.blacklist=ionic` via MachineConfig              | Persistent           |
| Firmware verify     | `nicctl show version firmware`                            | -                    |
| Driver verify       | `dkms status` or `lsmod \| grep ionic`                   | -                    |

### Layer 2: NIC-Level Configuration (via nicctl)

These settings do NOT persist across reboots unless personas are used.

#### QoS / PFC / DCQCN

```bash
# Enable PFC with pause frames
nicctl update port -p <port> --pause-type pfc --rx-pause enable --tx-pause enable

# DSCP-to-priority mappings
nicctl update qos dscp-to-priority --dscp 24 --priority 3    # Data traffic
nicctl update qos dscp-to-priority --dscp 46 --priority 6    # CNP/CTS

# Enable no-drop for priority 3 (RoCE data)
nicctl update qos pfc --priority 3 --no-drop enable

# Scheduling: 99% to Q3, 1% to Q0, strict priority for Q6
nicctl update qos scheduling --priority 3,0,6 --dwrr 99,1,0 --rate-limit 0,0,10
```

#### DCQCN Parameters

```bash
nicctl update dcqcn -r <roce_dev> -i 1 \
  --token-bucket-size 800000 \
  --ai-rate 160 \
  --alpha-update-interval 1 \
  --alpha-update-g 512 \
  --initial-alpha-value 64 \
  --rate-increase-byte-count 431068 \
  --hai-rate 300 \
  --rate-reduce-monitor-period 1 \
  --rate-increase-threshold 1 \
  --rate-increase-interval 1 \
  --cnp-dscp 46
```

#### Relaxed Ordering & Speed Mask

```bash
# Enable PCIe relaxed ordering
nicctl ordering set <interface> relaxed enable

# Disable speeds below 400G
nicctl speed-mask set <interface> 0x4
```

#### MTU

```bash
# Set MTU 9000 on all backend interfaces
ip link set <interface> mtu 9000
```

#### Personas (for persistence across reboots)

```bash
# View current persona
nicctl show card --persona

# Apply persona (persists config across reboots)
nicctl persona set <interface> <persona-type>
```

### Layer 3: Host / OS / Kernel Configuration

| Setting                 | How to Configure                                                     | Purpose                                   |
| ----------------------- | -------------------------------------------------------------------- | ----------------------------------------- |
| RDMA namespace mode     | Kernel arg `ib_core.netns_mode=0` via MachineConfig                  | Allow pods to access host RDMA devices    |
| Disable ACS             | Kernel arg `iommu=pt` or `pci=noacs` via MachineConfig               | Required for GPU-NIC peer-to-peer DMA     |
| Disable NUMA balancing  | Kernel arg `numa_balancing=0` via MachineConfig                      | Prevent NUMA migration overhead           |
| TCP ECN                 | Sysctl `net.ipv4.tcp_ecn=1` via MachineConfig                       | ECN for RCCL control traffic              |
| GDR peermem module      | `modprobe ib_peer_mem` or via MachineConfig                          | GPU Direct RDMA via peermem               |
| GDR DMABUF              | Kernel 5.12+ with `CONFIG_DMABUF` + ROCm `hsa_amd_portable_export_dmabuf()` | GPU Direct RDMA via DMABUF          |
| Fan speed (BMC)         | Redfish API: set fan mode to FullSpeed (~25,000 RPM)                 | NIC thermal management (~50C target)      |
| BIOS: Hot Plug          | Enable in BIOS                                                       | Required for profile updates / PCI reset  |
| BIOS: PCI AER           | Disable if link-down events not handled                              | Prevent OS crash on NIC reset             |

### Layer 4: Kubernetes / OpenShift Configuration

| Component                    | Configuration                                                                  | Purpose                              |
| ---------------------------- | ------------------------------------------------------------------------------ | ------------------------------------ |
| NetworkConfig CR             | Driver enable, device plugin, metrics exporter, CNI plugins                    | AMD Network Operator orchestration   |
| Device Plugin ConfigMap      | Vendor `1dd8`, PF device `1002`, VF device `1003`, `isRdma` flag              | Register NIC resources for scheduling |
| NetworkAttachmentDefinition  | `host-device` CNI + whereabouts IPAM on `192.168.200.0/24`                    | Attach RDMA NICs to pods             |
| SriovNetworkNodePolicy       | `numVfs`, `nicSelector`, `deviceType: netdevice`                              | Create SR-IOV VFs                    |
| MPI Operator                 | Kubeflow MPI Operator v0.8.0                                                  | Distributed RCCL job execution       |

---

## RCCL Environment Variables Reference

From UG1801 and the AMD Cluster Validation Framework:

| Variable                                       | Value     | Purpose                                    |
| ---------------------------------------------- | --------- | ------------------------------------------ |
| `NCCL_IB_GID_INDEX`                            | `1`       | Select RoCEv2 GID (IPv4-mapped)            |
| `NCCL_NET_OPTIONAL_RECV_COMPLETION`            | `0`       | Require receive completions                |
| `NCCL_GDR_FLUSH_DISABLE`                       | `1`       | Disable GDR flush for performance          |
| `RCCL_GDR_FLUSH_GPU_MEM_NO_RELAXED_ORDERING`  | `0`       | Allow relaxed ordering on GPU mem flush    |
| `NCCL_IB_USE_INLINE`                           | `1`       | Use inline data for small messages         |
| `NCCL_IB_PCI_RELAXED_ORDERING`                 | `1`       | PCIe relaxed ordering for IB transport     |
| `IONIC_LOCKFREE`                               | `all`     | Lock-free mode for ionic driver            |
| `NCCL_NET_PLUGIN`                              | `librccl-anp.so` | AMD ANP network plugin              |
| `NCCL_DMABUF_ENABLE`                           | `0`       | DMABUF for GDR (0=off, 1=on)              |
| `NCCL_BUFFSIZE`                                | `2097152` | 2MB buffer size                            |
| `NCCL_MAX_NCHANNELS`                           | `16`      | Max communication channels                 |
| `NCCL_DEBUG`                                   | `INFO`    | Debug verbosity                            |
| `NCCL_IGNORE_CPU_AFFINITY`                     | `1`       | Ignore CPU affinity constraints            |
| `NCCL_IB_TC`                                   | varies    | Traffic class for IB                       |
| `NCCL_IB_QPS_PER_CONNECTION`                   | varies    | Queue pairs per connection                 |
| `NCCL_MIN_NCHANNELS`                           | varies    | Minimum communication channels             |

---

## NIC Profile Comparison

| Profile        | Config Name                    | PFs | VFs per PF | RDMA on PF  | RDMA on VF | Use Case                          |
| -------------- | ------------------------------ | --- | ---------- | ----------- | ---------- | --------------------------------- |
| default        | `device_config_rdma_1x400G`    | 1   | 0          | Full        | N/A        | Single-tenant bare-metal RDMA     |
| pf1_vf1        | `device_config_pf1_vf1_llc`    | 1   | 1          | Skinny      | Full       | Container RDMA via VF passthrough |
| hnic_pf1_vf8   | `device_config_pf1_vf8_hnic`   | 1   | 8          | Skinny      | No         | High-density VF without RDMA      |

---

## Verification Commands

```bash
# NIC firmware version
nicctl show version firmware

# RDMA devices visible
rdma link
ibv_devinfo -v | grep GID

# Port status and temperature
nicctl show port

# QoS configuration
nicctl show qos

# DCQCN settings
nicctl show dcqcn

# RDMA queue stats
nicctl show rdma queue

# Driver status
dkms status
lsmod | grep ionic

# From OpenShift
oc exec -n openshift-amd-network <metrics-pod> -- nicctl show card
oc exec -n openshift-amd-network <metrics-pod> -- nicctl show port
```

---

## Gap Analysis vs. This Repo's Configuration

Assessed on 2026-05-12 against `network-operator/` in this repo.

| #  | Gap                                          | Docs Requirement                                                                                    | Severity    | Notes                                             |
| -- | -------------------------------------------- | --------------------------------------------------------------------------------------------------- | ----------- | ------------------------------------------------- |
| 1  | RDMA namespace mode commented out            | `ib_core.netns_mode=0` required for RDMA in pods                                                    | High        | Uncomment in kustomization.yaml if not applied    |
| 2  | No QoS/DCQCN/PFC NIC config                 | PFC on P3, DSCP 24->P3, DSCP 46->P6, DCQCN params, scheduling                                     | High        | May be in amd-validated-design/ Ansible           |
| 3  | No MTU 9000                                  | Required on all backend interfaces per ROCm MoRI guide                                              | Medium-High | Add to NADs or NetworkConfig                      |
| 4  | No relaxed ordering                          | `nicctl ordering set` + `NCCL_IB_PCI_RELAXED_ORDERING=1` env var                                   | Medium      | NIC-level + RCCL env var                          |
| 5  | No speed mask (400G only)                    | Disable speeds below 400G to prevent AN fallback                                                    | Medium      | NIC-level config                                  |
| 6  | No ACS disable / NUMA balancing disable      | Kernel args `iommu=pt` and `numa_balancing=0`                                                       | Medium      | MachineConfig                                     |
| 7  | No TCP ECN sysctl                            | `net.ipv4.tcp_ecn=1` for RCCL control traffic                                                      | Low-Medium  | MachineConfig with sysctl                         |
| 8  | No GDR / peermem / DMABUF                    | UG1801 full GDR section; `NCCL_DMABUF_ENABLE=0` currently                                          | Low         | May be intentional                                |
| 9  | No persona automation                        | NIC config lost on reboot without personas                                                          | Medium      | Tied to gap #2                                    |
| 10 | Stale NAD comment                            | Single-pod NAD says "NICs don't support SR-IOV" but SR-IOV stage exists                             | Cosmetic    | Fix comment                                       |
| 11 | Missing NCCL_IB_PCI_RELAXED_ORDERING env var | Listed in UG1801 RCCL docs but absent from RCCL_ENV_VARS ConfigMap                                  | Low-Medium  | Add to cluster-validation-config.yaml             |
