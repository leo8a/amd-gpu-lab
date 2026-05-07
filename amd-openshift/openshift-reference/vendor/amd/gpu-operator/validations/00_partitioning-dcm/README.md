# AMD GPU Partitioning via DCM

## What is GPU Partitioning via DCM?

DCM (Dynamic Compute Multiplexing) is AMD's technology that enables partitioning a single physical AMD Instinct GPU into multiple virtual GPU instances. This allows:

- **Multi-tenancy**: Multiple workloads can share the same GPU with hardware-level isolation
- **Resource optimization**: Dynamically allocate GPU compute resources based on workload needs
- **Flexible partitioning**: Configure partition profiles (e.g., 1g.5gb, 2g.10gb, 3g.20gb) to split GPU memory and compute units

## Key Features

- Hardware-enforced isolation between partitions
- Support for AMD Instinct MI-series GPUs
- Integration with Kubernetes via AMD GPU Operator
- Dynamic partition profile application without host reboot

## Reference Documentation

- [Applying Partition Profiles](https://instinct.docs.amd.com/projects/gpu-operator/en/latest/dcm/applying-partition-profiles.html)

---

## Valid combinations (MI300X)

### Compatibility matrix

| Compute mode | # compute partitions | Compatible memory modes | Officially highlighted by AMD |
|---|---:|---|---|
| **SPX** | 1 | NPS1 | ✅ SPX + NPS1 |
| **DPX** | 2 | NPS1, NPS2 | ✅ DPX + NPS2 |
| **QPX** | 4 | NPS1, NPS2, NPS4 | ⚠️ Limited docs |
| **CPX** | 8 | NPS1, NPS2, NPS4 | ✅ CPX + NPS4 |

### Partition modes (quick reference)

- **Compute partitioning**
  - **SPX**: all 8 XCDs as **1** logical GPU
  - **DPX**: **4 XCDs/partition** → **2** logical GPUs
  - **QPX**: **2 XCDs/partition** → **4** logical GPUs
  - **CPX**: **1 XCD/partition** → **8** logical GPUs
- **Memory partitioning (NPS)**
  - **NPS1**: unified memory pool (**1 NUMA domain**)
  - **NPS2**: split memory (**2 NUMA domains**)
  - **NPS4**: split memory (**4 NUMA domains**)

### Constraints / rules of thumb

1. **Memory ≤ Compute**: number of memory partitions must be ≤ number of compute partitions  
   - Example: ❌ **SPX + NPS4** (1 compute < 4 memory)
2. **Even XCD requirement**: partitions must contain an even number of XCDs (**2, 4, 6, 8**)
3. **Recommended pairings**
   - **CPX + NPS4**: maximum partitioning (8 GPUs; best for multi-tenant)
   - **DPX + NPS2**: balanced locality
   - **SPX + NPS1**: maximum performance per GPU (single tenant)
4. **Avoid mixed memory modes** (e.g., NPS1 + NPS4) for simple single-node setups

### Official documentation

- [MI300X partitioning overview](https://instinct.docs.amd.com/projects/amdgpu-docs/en/latest/gpu-partitioning/mi300x/overview.html)
- [MI300X quick start guide](https://instinct.docs.amd.com/projects/amdgpu-docs/en/latest/gpu-partitioning/mi300x/quick-start-guide.html)
- [Compute & memory modes (ROCm blog)](https://rocm.blogs.amd.com/software-tools-optimization/compute-memory-modes/README.html)
- [GPU partitioning index](https://instinct.docs.amd.com/projects/amdgpu-docs/en/latest/gpu-partitioning/index.html)

> Note: **QPX** appears in hardware capabilities but has limited official documentation coverage. The most commonly highlighted configurations are **SPX+NPS1**, **DPX+NPS2**, and **CPX+NPS4**.
