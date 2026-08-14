# Two-Node GPUDirect RDMA with DRA PCIe Root Alignment

Validates GPU-to-GPU RDMA write bandwidth between two nodes using DRA (Dynamic Resource Allocation) to co-locate the GPU and NIC on the **same PCIe root complex**. This eliminates the NUMA-crossing penalty observed in the [device-plugin-based GDR test](../02_multi-node-gdr/) where K8s allocates GPU and NIC independently.

## Problem Statement

The standard `02_multi-node-gdr` test requests `amd.com/gpu: 1` and `amd.com/nic: 1` via device plugins. Since device plugins allocate resources independently, the GPU and NIC may land on different NUMA nodes or different PCIe root complexes:

| Scenario                    | Observed bandwidth | % of 400G line rate |
| --------------------------- | ------------------ | ------------------- |
| Same PCIe root (optimal)    | ~391 Gb/s          | 98%                 |
| Same NUMA, different root   | ~360 Gb/s          | 90%                 |
| Cross-NUMA                  | ~318 Gb/s          | 80%                 |

### PCIe Topology (SMC6217GPU / MI325X)

Each GPU+NIC pair shares a PCIe root port on these systems:

| PCIe Root          | GPU            | NIC (RDMA)               | NUMA |
| ------------------ | -------------- | ------------------------ | ---- |
| `pci0000:00`       | `0000:05:00.0` | `0000:09:00.0` (ionic_0) | 0    |
| `pci0000:10`       | `0000:15:00.0` | `0000:19:00.0` (ionic_1) | 0    |
| `pci0000:60`       | `0000:65:00.0` | `0000:69:00.0` (ionic_2) | 0    |
| `pci0000:70`       | `0000:75:00.0` | `0000:79:00.0` (ionic_3) | 0    |
| `pci0000:80`       | `0000:85:00.0` | `0000:89:00.0` (ionic_4) | 1    |
| `pci0000:90`       | `0000:95:00.0` | `0000:99:00.0` (ionic_5) | 1    |
| `pci0000:e0`       | `0000:e5:00.0` | **none**                 | 1    |
| `pci0000:f0`       | `0000:f5:00.0` | `0000:f9:00.0` (ionic_6) | 1    |

## Solution: DRA + matchAttribute

DRA allows requesting GPU and NIC in the same `ResourceClaimTemplate` with a `matchAttribute` constraint on `resource.kubernetes.io/pcieRoot`. The scheduler only allocates pairs where both devices report the same PCIe root complex value.

```yaml
constraints:
- requests: [gpu, nic]
  matchAttribute: "resource.kubernetes.io/pcieRoot"
```

This requires two DRA drivers publishing the same standard attribute:

| Driver              | Publishes                              | Manages         |
| ------------------- | -------------------------------------- | --------------- |
| AMD GPU DRA driver  | `resource.kubernetes.io/pcieRoot`      | GPU allocation  |
| DRANET              | `resource.kubernetes.io/pcieRoot`      | NIC allocation  |

## Prerequisites

### 1. Enable AMD GPU DRA driver

DRA and the legacy device plugin are mutually exclusive. Enable DRA on the DeviceConfig with the fixed image that supports multi-driver claims:

```bash
oc patch deviceconfig amdgpu-driver-install -n openshift-amd-gpu --type merge \
  -p '{"spec":{
    "draDriver":{
      "enable":true,
      "image":"quay.io/lochoa/k8s-gpu-dra-driver:multi-driver-fix",
      "imagePullPolicy":"Always"
    },
    "devicePlugin":{"enableDevicePlugin":false}
  }}'
```

Verify GPU ResourceSlices appear with `pcieRoot`:

```bash
oc get resourceslices -o json | jq '
  .items[] | select(.spec.driver == "gpu.amd.com") |
  .spec.devices[] | {name, pcieRoot: .attributes["resource.kubernetes.io/pcieRoot"].string,
    pciAddr: .attributes["resource.kubernetes.io/pciBusID"].string}'
```

### 2. Install DRANET

DRANET is a Kubernetes-SIGs project that discovers NICs and publishes them as DRA resources with topology attributes.

```bash
# Install DRANET DaemonSet
kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/dranet/refs/heads/main/install.yaml

# On OpenShift: grant privileged SCC to the DRANET service account
oc adm policy add-scc-to-user privileged -z dranet -n kube-system
```

Verify NIC ResourceSlices appear with `pcieRoot` and RDMA flag:

```bash
oc get resourceslices -o json | jq '
  .items[] | select(.spec.driver == "dra.net") |
  .spec.devices[] | {name,
    pcieRoot: .attributes["resource.kubernetes.io/pcieRoot"].string,
    rdma: .attributes["dra.net/rdma"].bool,
    ifName: .attributes["dra.net/ifName"].string}'
```

### 3. Verify cross-driver alignment

Both drivers must publish `resource.kubernetes.io/pcieRoot` with matching format (e.g., `pci0000:00`). Confirm with:

```bash
oc get resourceslices -o json | jq -r '
  .items[] | .spec as $s | .spec.devices[] |
  "\($s.driver)\t\(.name)\t\(.attributes["resource.kubernetes.io/pcieRoot"].string // "N/A")"
' | grep -v N/A | sort -k3
```

### Other prerequisites

| Requirement       | Details                                                               |
| ----------------- | --------------------------------------------------------------------- |
| `ib_peer_mem`     | Kernel module loaded (`lsmod \| grep ib_peer_mem`)                    |
| Node labels       | `feature.node.kubernetes.io/amd-nic=true`                             |
| Physical links    | At least 2 nodes with Pollara 400 NICs connected (carrier up)         |
| NIC QoS           | PFC + DCQCN configured — see [nic-prereqs.md](../docs/nic-prereqs.md) |
| Container image   | `quay.io/lochoa/amd-tools:gdr`                                        |

## Run

```bash
oc apply -k .
oc wait pod/rdma-server-gdr-dra -n openshift-amd-network --for=condition=ready --timeout=180s
oc logs -n openshift-amd-network rdma-server-gdr-dra
oc logs -n openshift-amd-network -l job-name=rdma-client-gdr-dra
```

Or via the parent Makefile:

```bash
cd .. && make multi-node-gdr-dra
```

## Results

**391.55 Gb/s** — 98% of 400G line rate, with GPU and NIC co-located on the same PCIe root via DRA `matchAttribute`:

| Test                    | GPU-NIC placement    | Bandwidth   | % line rate |
| ----------------------- | -------------------- | ----------- | ----------- |
| `02_multi-node-gdr`     | Cross-NUMA (random)  | 318.18 Gb/s | 80%         |
| `03_multi-node-gdr-dra` | Same PCIe root (DRA) | 391.55 Gb/s | 98%         |

```logs
GPU: 0000:75:00.0  root=pci0000:70/0000:70:01.1  numa=0
NIC: 0000:79:00.0  root=pci0000:70/0000:70:01.1  numa=0  rdma=ionic_3
OK: GPU and NIC on same PCIe root (pci0000:70/0000:70:01.1)
---
 #bytes     #iterations    BW peak[Gb/sec]    BW average[Gb/sec]   MsgRate[Mpps]
 1048576    280066           0.00               391.55              0.046677
```

## Cleanup

```bash
# Delete test resources
oc delete -k .

# Restore GPU device plugin (disable DRA)
oc patch deviceconfig amdgpu-driver-install -n openshift-amd-gpu --type merge \
  -p '{"spec":{"draDriver":{"enable":false},"devicePlugin":{"enableDevicePlugin":true}}}'

# Remove DRANET
kubectl delete -f https://raw.githubusercontent.com/kubernetes-sigs/dranet/refs/heads/main/install.yaml
oc adm policy remove-scc-from-user privileged -z dranet -n kube-system
```

## Status

**Experimental** — validated 2026-06-11 on smc6217gpu/smc6216gpu (MI325X, Pollara 400, OCP 4.18):

- [x] AMD GPU DRA driver publishes `resource.kubernetes.io/pcieRoot` (e.g., `pci0000:00`)
- [x] DRANET discovers AMD Pensando Pollara 400 NICs (ionic driver, vendor: `AMD Pensando Systems`)
- [x] DRANET publishes `resource.kubernetes.io/pcieRoot` for ionic devices
- [x] Cross-driver `matchAttribute` constraint works — scheduler correctly co-allocates GPU+NIC on same PCIe root
- [x] **FIXED**: AMD GPU DRA driver multi-driver claim support (see below)

### Fix: AMD GPU DRA driver multi-driver ResourceClaims

When a ResourceClaim contains devices from multiple drivers (GPU from `gpu.amd.com` + NIC from `dra.net`), the kubelet calls `NodePrepareResources` on all drivers for the entire claim. Each driver must filter for its own devices and skip the rest. The upstream AMD GPU DRA driver did not do this — it attempted to prepare the NIC device as a GPU and failed:

```logs
FailedPrepareDynamicResources: prepare failed: requested GPU is not allocatable: pci-0000-99-00-0
```

**Fix**: A one-line filter in `prepareDevices()` (`cmd/gpu-kubeletplugin/state.go`) that skips devices where `result.Driver != consts.DriverName`. This fix is available in `quay.io/lochoa/k8s-gpu-dra-driver:multi-driver-fix` but needs to be cherry-picked into the container image tag used by the GPU operator release. The upstream repo is [ROCm/k8s-gpu-dra-driver](https://github.com/ROCm/k8s-gpu-dra-driver).

### Verified allocation (before the blocker hit)

The scheduler successfully allocated GPU+NIC pairs on matching PCIe roots:

```logs
GPU  gpu-41-168      driver=gpu.amd.com  pcieRoot=pci0000:90  pci=0000:95:00.0
NIC  pci-0000-99-00-0  driver=dra.net      pcieRoot=pci0000:90  pci=0000:99:00.0
```

## Reference

- [kubernetes-sigs/dranet](https://github.com/kubernetes-sigs/dranet) — DRA network driver
- [NVIDIA+DRANET alignment example](https://github.com/kubernetes-sigs/dranet/blob/main/examples/demo_nvidia_dranet/resourceclaims.yaml)
- [AWS GPU+EFA alignment example](https://github.com/kubernetes-sigs/dranet/blob/main/examples/aws_eks_examples/gpu-efa/resource-claim-template.yaml)
- [AMD GPU DRA driver blog](https://rocm.blogs.amd.com/software-tools-optimization/dra-gpu/README.html)
- [DRANET research paper](https://arxiv.org/html/2506.23628v1) — reports 59.6% bandwidth gain with topology alignment

## Files

| File                            | Purpose                                                         |
| ------------------------------- | --------------------------------------------------------------- |
| `00_deviceclass-dranet.yaml`    | DeviceClass for DRANET (`device.driver == "dra.net"`)           |
| `01_resourceclaimtemplate.yaml` | GPU+NIC DRA claim with PCIe root alignment constraint           |
| `02_serviceaccount.yaml`        | ServiceAccount with privileged SCC                              |
| `03_rdma-server.yaml`           | RDMA GDR server pod using DRA claims                            |
| `04_rdma-client.yaml`           | RDMA GDR client job using DRA claims                            |
