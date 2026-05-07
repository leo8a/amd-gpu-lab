# SR-IOV NIC Assignment Test (pf1_vf1 Profile)

Test to verify SR-IOV Virtual Function (VF) assignment to a pod using AMD Pensando AI NICs.

## ✅ AMD Pensando AI NICs Support SR-IOV with pf1_vf1 Profile

**AMD Pensando Pollara 400G AI NICs support standard PCIe SR-IOV when configured with the `pf1_vf1` NIC profile:**

- **Standard SR-IOV support**: After updating to `pf1_vf1` profile, NICs expose standard sysfs SR-IOV files
- **OpenShift SR-IOV Operator compatible**: Works with standard SR-IOV Network Operator
- **Real PCIe VFs**: Virtual Functions are standard PCIe SR-IOV VFs (device ID 1dd8:1003)
- **Profile-dependent**: Default profile does NOT support SR-IOV; `pf1_vf1` or `hnic_pf1_vf8` profile required

**Verification:**

```bash
# AMD Pensando AI NIC with pf1_vf1 profile - HAS SR-IOV support ✓
ssh core@node
cat /sys/class/net/enp9s0np0/device/sriov_totalvfs  # Returns 1
cat /sys/class/net/enp9s0np0/device/sriov_numvfs    # Returns 1 (if configured)
```

**Resource Types:**

- `openshift.io/vnic` - SR-IOV Virtual Functions (exposed by SR-IOV device plugin)
- `amd.com/nic` - Physical Functions (exposed by AMD device plugin)

## Prerequisites

- AMD Network Operator deployed
- **OpenShift SR-IOV Network Operator installed** (required for VF management)
- **NIC profile updated to `pf1_vf1`** (see [Update AI NIC Profile](../../docs/update-ai-nic-profile.md))
- **Firmware partitions A and B synchronized** to same version (see [Update AI NIC Firmware](../../docs/update-ai-nic-firmware.md))
- **Node rebooted** after profile update to activate VF capability
- Nodes labeled with `feature.node.kubernetes.io/amd-nic=true`

**Check current NIC profile** (`totalvfs=1` → pf1_vf1, `totalvfs=8` → hnic_pf1_vf8, `totalvfs=0` → default):

```bash
# totalvfs=1 means pf1_vf1 (required), totalvfs=8 means hnic_pf1_vf8, totalvfs=0 means default
oc debug node/<node-name> -- chroot /host bash -c \
  'for pci in $(lspci -d 1dd8:1002 -D | awk "{print \$1}"); do
     echo "PCI $pci: totalvfs=$(cat /sys/bus/pci/devices/$pci/sriov_totalvfs)";
   done'
```

## Run Test

```bash
# Apply all resources (policy, network, test pod)
oc apply -k .

# Check pod status
oc get pod -n openshift-amd-network test-amd-sriov

# Verify VF interface in pod
oc exec -n openshift-amd-network test-amd-sriov -- ip addr show
```

## Expected Behavior

- Pod gets access to AMD Pensando SR-IOV VF (standard PCIe VF, device 1dd8:1003)
- **net1** interface appears in pod with IP from whereabouts IPAM (192.168.100.100/24)
- VF is moved into pod network namespace via SR-IOV CNI
- Interface state shows "DOWN" (no carrier) - expected, not connected to anything
- **Will fail if `openshift.io/vnic` resources are not available** (VFs not created)

## Verification

**Check interfaces in pod:**

```bash
oc exec -n openshift-amd-network test-amd-sriov -- ip addr show

# Expected output:
# 110: net1: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc mq state DOWN
#     link/ether 04:90:81:36:9e:29 brd ff:ff:ff:ff:ff:ff
#     inet 192.168.100.100/24 brd 192.168.100.255 scope global net1
```

**Check PCI device assignment:**

```bash
oc get pod -n openshift-amd-network test-amd-sriov -o jsonpath='{.metadata.annotations.k8s\.v1\.cni\.cncf\.io/network-status}' | jq '.[1]'

# Expected output shows PCI address of assigned VF:
# {
#   "name": "openshift-amd-network/amd-vnic-network",
#   "interface": "net1",
#   "device-info": {
#     "type": "pci",
#     "pci": { "pci-address": "0000:99:00.1" }
#   }
# }
```

**Check resource allocation:**

```bash
oc describe node <node-name> | grep "openshift.io/vnic"

# Expected: Shows 1 VF allocated out of 7 total
```

## Important Notes

**AMD Pensando AI NICs with pf1_vf1 profile:**

- **1 VF per physical NIC** (standard PCIe SR-IOV VF)
- **SR-IOV Operator required**: OpenShift SR-IOV Network Operator manages VF configuration
- **SR-IOV Device Plugin**: Exposes VFs as `openshift.io/vnic` resource
- **Profile-dependent**: Must update NIC profile to `pf1_vf1` before SR-IOV works

**How to enable SR-IOV on AMD Pensando AI NICs:**

1. Update firmware to matching versions on partitions A and B
2. Update NIC profile to `pf1_vf1` (see [Update AI NIC Profile](../../docs/update-ai-nic-profile.md))
3. Reboot node to activate new profile
4. Verify `sriov_totalvfs` shows 1
5. Deploy SR-IOV Network Operator and SriovNetworkNodePolicy (included in this test)

## Cleanup

```bash
oc delete -k .
```

## Files

- `00_amd-device-plugin-config.yaml` - AMD Device Plugin ConfigMap (required for pf1_vf1 profile with isRdma: true)
- `01_sriov-amd-vnic-policy.yaml` - SriovNetworkNodePolicy (vendor: 1dd8, deviceID: 1002, numVfs: 1)
- `02_sriov-amd-vnic-net.yaml` - SriovNetwork CR (auto-creates NetworkAttachmentDefinition with SR-IOV CNI + whereabouts IPAM)
- `03_sriov-nic-test.yaml` - Test pod requesting `openshift.io/vnic` resource with net1 SR-IOV interface
