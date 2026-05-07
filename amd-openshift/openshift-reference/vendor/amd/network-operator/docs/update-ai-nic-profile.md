# Update AMD Pensando AI Pollara 400G NIC Profile

This procedure updates the NIC profile to enable SR-IOV Virtual Functions on AMD Pensando Pollara 400G NICs.

## Prerequisites

- AMD AI NIC firmware bundle extracted (see [Update AI NIC Firmware](./update-ai-nic-firmware.md))
- SSH access to the target node
- Root privileges on the node
- **Important:** Firmware partitions A and B must be on the same version
- **Important:** Node requires a reboot after profile update

## Reference

- [AMD Pensando Pollara AI 400G NIC Operations Guide (UG1801)](https://docs.amd.com/r/en-US/ug1801-ai-nic-pollara-400-ops-guide)
  - Also available locally: [amd-validated-design/assets/Pollara AI NIC/](../../../../../amd-validated-design/assets/Pollara%20AI%20NIC/)
- [AMD Instinct System Acceptance - NIC Installation](https://instinct.docs.amd.com/projects/system-acceptance/en/latest/network/nic-installation.html#update-firmware)
- [Update AI NIC Firmware](./update-ai-nic-firmware.md) - Firmware update procedure (prerequisite)

---

## Step 0: Check Current Profile

**SSH to the node:**

```bash
ssh -i ${SSH_KEY} core@${NODE_IP}
sudo -i
cd /root/ainic_bundle_${AINIC_VERSION}/host_sw_pkg
```

**Check current profile:**

```bash
./nicctl/bin/nicctl show card profile
```

**Expected output:**

```bash
Profile name                   : default
Description                    : Non-breakout mode 1x400G
Device config                  : device_config_rdma_1x400G
Port profile : 
  Port                         : 1
    Breakout mode              : none
```

---

## Step 1: Verify Firmware Versions Match

Before updating the profile, verify all NICs are on the same firmware version:

```bash
./nicctl/bin/nicctl show card --detail | grep "Firmware version"
```

**Expected output (all NICs should show the same version):**

```bash
Firmware version               : 1.117.5-a-56
Firmware version               : 1.117.5-a-56
Firmware version               : 1.117.5-a-56
Firmware version               : 1.117.5-a-56
Firmware version               : 1.117.5-a-56
Firmware version               : 1.117.5-a-56
Firmware version               : 1.117.5-a-56
```

**Note:** You'll see one "Firmware version" line per NIC (7 total for a system with 7 NICs). All should match. If versions differ, run firmware update first (see `update-ai-nic-firmware.md`).

---

## Step 2: Update NIC Profile

Choose **one** of the following profiles based on your SR-IOV requirements:

### Option A: Profile `pf1_vf1` (1 VF per NIC)

**Update to 1 Physical Function + 1 Virtual Function:**

```bash
./nicctl/bin/nicctl update card profile -i ../firmware/ainic_fw_salina.tar --profile pf1_vf1
```

**Expected output:**

```bash
----------------------------------------------------------------------------------
Card Id                                 Stage                   Status            
----------------------------------------------------------------------------------
42424650-4c32-3532-3230-313235000000    Done                    100% [00:04.125]  
42424650-4c32-3532-3230-313938000000    Done                    100% [00:04.027]  
...

NIC 42424650-4c32-3532-3230-313235000000 (0000:06:00.0) : Successful
NIC 42424650-4c32-3532-3230-313938000000 (0000:16:00.0) : Successful
...
```

### Option B: Profile `hnic_pf1_vf8` (8 VFs per NIC)

**Update to 1 Physical Function + 8 Virtual Functions:**

```bash
./nicctl/bin/nicctl update card profile -i ../firmware/ainic_fw_salina.tar --profile hnic_pf1_vf8
```

**Expected output:** Same format as Option A, but with 8 VFs available.

**Notes:**

- Profile update takes approximately 4-5 minutes per NIC
- Updates all NICs simultaneously by default
- No immediate impact - changes activate after reboot
- **SSH connection may drop** during the update process (this is normal)
- **Node may reboot automatically** after profile update completes

---

## Step 3: Verify Profile Update

**Check updated profile:**

```bash
./nicctl/bin/nicctl show card profile
```

**Expected output for `pf1_vf1`:**

```bash
Profile name                   : pf1_vf1
Description                    : single VF profile
Device config                  : device_config_pf1_vf1_llc
```

**Expected output for `hnic_pf1_vf8`:**

```bash
Profile name                   : hnic_pf1_vf8
Description                    : single PF 8 VF Host NIC profile
Device config                  : device_config_pf1_vf8_hnic
```

---

## Step 4: Reboot Node

After a successful profile update, the node **must be rebooted** to activate the new profile.

**Note:** The node may have already rebooted automatically after the profile update. If your SSH connection dropped, wait a few minutes and try to reconnect. If the node is already back online, proceed to Step 5 to verify.

**If the node hasn't rebooted yet:**

```bash
# From the node (as root)
reboot

# Or from local machine
ssh -i ${SSH_KEY} core@${NODE_IP} sudo reboot
```

---

## Step 5: Verify VF Capability

After the node reboots, verify SR-IOV VF support:

```bash
# SSH back to the node
ssh -i ${SSH_KEY} core@${NODE_IP}
sudo -i

# Check total VFs available per NIC
for pci in 0000:09:00.0 0000:19:00.0 0000:69:00.0 0000:79:00.0 0000:89:00.0 0000:99:00.0 0000:f9:00.0; do
  totalvfs=$(cat /sys/bus/pci/devices/$pci/sriov_totalvfs 2>/dev/null || echo "0")
  echo "PCI $pci: totalvfs=$totalvfs"
done
```

**Expected output for `pf1_vf1`:**

```bash
PCI 0000:09:00.0: totalvfs=1
PCI 0000:19:00.0: totalvfs=1
...
```

**Expected output for `hnic_pf1_vf8`:**

```bash
PCI 0000:09:00.0: totalvfs=8
PCI 0000:19:00.0: totalvfs=8
...
```

---

## Step 6: Update SR-IOV Policy (OpenShift)

Update the SR-IOV policy `numVfs` to match your profile:

**For `pf1_vf1` profile:**

```bash
oc patch sriovnetworknodepolicy -n openshift-sriov-network-operator amd-vnic-policy \
  --type='json' -p='[{"op": "replace", "path": "/spec/numVfs", "value": 1}]'
```

**For `hnic_pf1_vf8` profile:**

```bash
oc patch sriovnetworknodepolicy -n openshift-sriov-network-operator amd-vnic-policy \
  --type='json' -p='[{"op": "replace", "path": "/spec/numVfs", "value": 8}]'
```

**Verify SR-IOV resources:**

```bash
oc get nodes <node-name> -o json | jq '.status.allocatable | with_entries(select(.key | contains("vnic")))'
```

**Expected:** `"openshift.io/vnic": "7"` for pf1_vf1, or `"openshift.io/vnic": "56"` for hnic_pf1_vf8 (7 NICs × 8 VFs).

---

## Troubleshooting

### Profile Update Fails: "Both firmware partitions must run same version"

**Cause:** Firmware-A and Firmware-B versions don't match.

**Solution:** Update firmware first (see `update-ai-nic-firmware.md`), reboot, then update profile.

### After Reboot: `totalvfs=0`

**Cause:** Profile update didn't persist or node didn't fully reboot.

**Solution:**

1. Verify profile with `nicctl show card profile`
2. If profile is still `default`, re-run the profile update command
3. Ensure clean reboot (not just service restart)

### SR-IOV Operator Fails: "NumVfs is larger than TotalVfs"

**Cause:** SR-IOV policy `numVfs` exceeds what the NIC profile supports.

**Solution:** Ensure SR-IOV policy `numVfs` matches profile (1 for pf1_vf1, ≤8 for hnic_pf1_vf8).

### Partial Profile Update: Some NICs Updated, Some Not

**Cause:** Profile update may fail for individual NICs if SSH connection drops during the process.

**Symptoms:** Running `nicctl show card profile` shows mixed profiles (e.g., 6 NICs on `hnic_pf1_vf8` and 1 NIC still on `pf1_vf1`).

**Solution:**

1. Find the card ID of the NIC(s) that failed to update:

   ```bash
   ./nicctl/bin/nicctl show card profile | grep -B2 "pf1_vf1"
   ```

2. Update the specific NIC by card ID:

   ```bash
   ./nicctl/bin/nicctl update card profile -i ../firmware/ainic_fw_salina.tar --profile hnic_pf1_vf8 --card <CARD_ID>
   ```

   Example:

   ```bash
   ./nicctl/bin/nicctl update card profile -i ../firmware/ainic_fw_salina.tar --profile hnic_pf1_vf8 --card 42424650-4c32-3532-3230-333537000000
   ```

3. Wait for update to complete and reboot the node again.

---

## Summary

1. ✅ **Step 0:** Check current profile
2. ✅ **Step 1:** Verify firmware versions match (A = B)
3. ✅ **Step 2:** Update NIC profile (`pf1_vf1` or `hnic_pf1_vf8`)
4. ✅ **Step 3:** Verify profile update
5. ✅ **Step 4:** Reboot node
6. ✅ **Step 5:** Verify VF capability (`sriov_totalvfs`)
7. ✅ **Step 6:** Update SR-IOV policy `numVfs` to match profile

**Key Points:**

- **Firmware must be synced** (A = B versions) before profile update
- **Node reboot required** to activate new profile
- **SR-IOV policy `numVfs`** must match profile capability
- Profile `pf1_vf1` = 1 VF per NIC (7 total)
- Profile `hnic_pf1_vf8` = 8 VFs per NIC (56 total)
