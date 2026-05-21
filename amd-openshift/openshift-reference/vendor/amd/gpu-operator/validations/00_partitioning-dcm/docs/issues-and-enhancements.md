# Issues and Enhancements identified

---

## Partitioning Persistence after Reboots

Should be solved in: [[Feature]: Orchestration of cluster partitioning workflow](https://github.com/ROCm/gpu-operator/issues/362).

GPU partitioning is **not persistent across reboots**. GPUs always boot in SPX + NPS1 (default) — no kernel parameters or BIOS settings exist to pre-configure partitioning. After reboot, DCM detects the profile label and attempts to re-apply, but fails because the node is not tainted, workloads are already running, and the `amdgpu` driver is in use (`modprobe -rv amdgpu` → `Module amdgpu is in use`). Manual re-partitioning (taint → label → verify → untaint) is required after every reboot.

---

## Enhancement: Block profiles not defined in the ConfigMap

DCM should validate that the requested profile exists in the ConfigMap **before** stopping GPU client services and entering the partition retry loop. Currently, an undefined profile (e.g., `cpx-profile-nps1`) passes through service shutdown and AMD SMI initialization before failing with `Selected Profile ... not found`. The fix adds an early lookup in `RetryPartition()` that sets the failure label and returns immediately if the profile is missing.

Proposed fix in `device-config-manager/pkg/config_manager/configmanager.go` — see local branch.

---

## Enhancement: Show available partitions in DeviceConfig CR status

After applying a partition profile (e.g., CPX + NPS4), the next valid profiles depend on what the hardware reports via `available_memory_partition`. For example, a node with BIOS 1.5 only supports `[NPS1, NPS4]`, so DPX + NPS2 silently fails. The DeviceConfig CR status should surface the per-node available compute and memory partitions so users can see what profiles are valid before attempting a partition change.

---

## Enhancement: Drop toleration patching — control-plane pods already survive the amd-dcm taint

The [AMD GPU partitioning docs](https://instinct.docs.amd.com/projects/gpu-operator/en/latest/dcm/applying-partition-profiles.html) recommend patching tolerations across ~30 control-plane namespaces before tainting the node. This step is unnecessary — all critical control-plane DaemonSets (OVN, Multus, DNS, etcd, apiserver, etc.) already carry a wildcard toleration (`operator: Exists`) that survives any `NoExecute` taint, including `amd-dcm=up:NoExecute`.

**Finding (2026-05-19):** Tested applying `amd-dcm=up:NoExecute` taint on both worker (smc6216gpu) and master (smc6217gpu) nodes **without** patching any tolerations. All critical control-plane DaemonSets survived — they carry a wildcard toleration (`operator: Exists`) by default. Only the GPU operands were evicted, which is the desired behavior. **Step 1 (toleration patching) is unnecessary and has been removed from the workflow.**

| Component                                      | Status      | Reason                                   |
| ---------------------------------------------- | ----------- | ---------------------------------------- |
| etcd, apiserver, controller-manager, scheduler | Running     | Wildcard toleration (`operator: Exists`) |
| OVN, Multus, DNS, MCD, node-exporter           | Running     | Wildcard toleration (`operator: Exists`) |
| DCM                                            | Running     | Explicit `amd-dcm=up` toleration         |
| device-plugin, node-labeller, metrics-exporter | **Evicted** | No matching toleration (expected)        |

Verify with:

```bash
# Check which pods survive and their toleration type
for pod in $(oc get pods -A --field-selector spec.nodeName=$NODE_NAME -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}'); do
  ns=$(echo $pod | cut -d/ -f1); name=$(echo $pod | cut -d/ -f2)
  wildcard=$(oc get pod $name -n $ns -o json | jq '[.spec.tolerations[]? | select(.operator == "Exists" and .key == null)] | length')
  amd=$(oc get pod $name -n $ns -o json | jq '[.spec.tolerations[]? | select(.key == "amd-dcm")] | length')
  echo "$pod: wildcard=$wildcard amd-dcm=$amd"
done
```
