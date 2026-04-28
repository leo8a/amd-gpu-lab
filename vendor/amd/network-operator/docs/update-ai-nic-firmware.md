# Update AMD Pensando AI Pollara 400G NIC Firmware

This procedure updates the firmware on AMD Pensando Pollara 400G NICs.

## Prerequisites

- AMD AI NIC firmware bundle (e.g., `ainic_bundle_1.117.5-a-56.tar.gz`)
- SSH access to the target node
- Root privileges on the node
- **Important:** Node will require a reboot after firmware update (~5-10 min downtime)

## Reference

- [AMD Pensando Pollara AI 400G NIC Operations Guide (UG1801)](https://docs.amd.com/r/en-US/ug1801-ai-nic-pollara-400-ops-guide)
  - Also available locally: [amd-validated-design/assets/Pollara AI NIC/](../../../../../amd-validated-design/assets/Pollara%20AI%20NIC/)
- [AMD Instinct System Acceptance - NIC Installation](https://instinct.docs.amd.com/projects/system-acceptance/en/latest/network/nic-installation.html#update-firmware)
- [Update AI NIC Profile](./update-ai-nic-profile.md) - SR-IOV VF configuration

---

## Step 0: Set Environment Variables

**Set these variables for your target node and firmware version:**

```bash
# Target node details
export TARGET_NODE="smc6217gpu.partner-accelerators.redhat.lab"
export NODE_IP="10.216.91.138"

# Firmware version to install
export AINIC_VERSION="1.117.5-a-56"
export AINIC_BUNDLE_FILENAME="ainic_bundle_${AINIC_VERSION}.tar.gz"

# Paths (adjust if needed)
export AINIC_BUNDLE_PATH="/home/leo8a/Projects/amd-gpu-lab/amd-validated-design/assets/Pollara AI NIC/${AINIC_VERSION}/${AINIC_BUNDLE_FILENAME}"
export SSH_KEY="/home/leo8a/Projects/amd-gpu-lab/amd-labs/amd-lab-virt/ssh/id_rsa"
```

**Verify firmware bundle exists locally:**

```bash
ls -lh "${AINIC_BUNDLE_PATH}"
```

---

## Step 1: Check Current Firmware Version (Optional)

Check the current firmware version from the cluster using devlink (no nicctl needed yet):

```bash
oc debug node/${TARGET_NODE} -- chroot /host bash -c "echo '=== AMD Pensando NIC Firmware Versions ==='; for pci in 08:00.2 18:00.2 68:00.2 78:00.2 88:00.2 98:00.2 f8:00.2; do serial=\$(devlink dev info pci/0000:\$pci 2>/dev/null | grep serial_number | awk '{print \$2}'); fw=\$(devlink dev info pci/0000:\$pci 2>/dev/null | grep 'fw.a35_uboota' | awk '{print \$2}'); cpld=\$(devlink dev info pci/0000:\$pci 2>/dev/null | grep 'fw.cpld' | head -1 | awk '{print \$2}'); [ -n \"\$fw\" ] && echo \"PCI \$pci (S/N:\$serial): FW \$fw, CPLD \$cpld\"; done"
```

**Note:** This uses the kernel's devlink interface which doesn't require nicctl.

---

## Step 2: Copy Bundle to Target Node

```bash
# Copy the firmware bundle to the node
scp -i ${SSH_KEY} ${AINIC_BUNDLE_PATH} core@${NODE_IP}:/var/home/core/
```

---

## Step 3: Extract Firmware Bundle and Host Software

**IMPORTANT:** The nicctl tool is inside this bundle - extract it first before trying to use it!

```bash
# SSH to the node
ssh -i ${SSH_KEY} core@${NODE_IP}

# Move bundle to /root and switch to root
sudo mv ainic_bundle_* /root/
sudo -i

# Extract the main bundle
cd /root
tar -xvf ${AINIC_BUNDLE_FILENAME}

# Extract the host software package (contains nicctl tool)
cd ainic_bundle_${AINIC_VERSION}
tar -xvf host_sw_pkg.tar.gz

# Verify extraction
ls -la host_sw_pkg/nicctl/bin/nicctl
ls -la firmware/ainic_fw_salina.tar
```

**Expected output:**

```bash
-rwxr-xr-x. 1 root root  92M ... host_sw_pkg/nicctl/bin/nicctl
-rw-r--r--. 1 root root 157M ... firmware/ainic_fw_salina.tar
```

---

## Step 4: Check NIC Information (Now that nicctl is available)

Now you can use nicctl to get detailed NIC information:

```bash
# Still as root in the extracted directory
cd /root/ainic_bundle_${AINIC_VERSION}/host_sw_pkg

# Show all NIC cards
./nicctl/bin/nicctl show card

# Show detailed firmware info
./nicctl/bin/nicctl show card --detail | grep "Id\|IPC BDF\|Firmware version"
```

**Example output:**

```bash
---------------------------------------------------------------------------------------------
Id                                      PCIe BDF       ASIC      F/W partition Serial number 
---------------------------------------------------------------------------------------------
42424650-4c32-3532-3230-313235000000    0000:08:00.0   salina    A             FPL25220125   
42424650-4c32-3532-3230-313938000000    0000:18:00.0   salina    A             FPL25220198   
42424650-4c32-3532-3230-333537000000    0000:68:00.0   salina    A             FPL25220357   
42424650-4c32-3532-3230-304536000000    0000:78:00.0   salina    A             FPL252200E6   
42424650-4c32-3532-3230-304446000000    0000:88:00.0   salina    A             FPL252200DF   
42424650-4c32-3532-3230-324635000000    0000:98:00.0   salina    A             FPL252202F5   
42424650-4c32-3532-3230-314333000000    0000:f8:00.0   salina    A             FPL252201C3   
```

**Note:** Save UUIDs only if you need to update specific NICs individually (rare).

---

## Step 5: Update NIC Firmware

**Update all NICs at once (recommended):**

```bash
# Navigate to host software directory (should already be here from Step 4)
cd /root/ainic_bundle_${AINIC_VERSION}/host_sw_pkg

# Update all NICs (takes ~3-5 minutes per NIC, ~25 minutes total for 7 NICs)
./nicctl/bin/nicctl update firmware -i ../firmware/ainic_fw_salina.tar --reset
```

**Expected output:**

```bash
----------------------------------------------------------------------------------------------
Card Id                                 Stage                               Progress          
----------------------------------------------------------------------------------------------
42424650-4c32-3532-3230-313235000000    Done                                100% [04:28.542]  
42424650-4c32-3532-3230-313938000000    Done                                100% [04:50.367]  
42424650-4c32-3532-3230-333537000000    Done                                100% [04:28.230]  
42424650-4c32-3532-3230-304536000000    Done                                100% [04:20.172]  
42424650-4c32-3532-3230-304446000000    Done                                100% [04:38.129]  
42424650-4c32-3532-3230-324635000000    Done                                100% [04:28.739]  
42424650-4c32-3532-3230-314333000000    Done                                100% [04:19.748]  

NIC 42424650-4c32-3532-3230-313235000000 (0000:08:00.0) : Successful
NIC 42424650-4c32-3532-3230-313938000000 (0000:18:00.0) : Successful
NIC 42424650-4c32-3532-3230-333537000000 (0000:68:00.0) : Successful
NIC 42424650-4c32-3532-3230-304536000000 (0000:78:00.0) : Successful
NIC 42424650-4c32-3532-3230-304446000000 (0000:88:00.0) : Successful
NIC 42424650-4c32-3532-3230-324635000000 (0000:98:00.0) : Successful
NIC 42424650-4c32-3532-3230-314333000000 (0000:f8:00.0) : Successful
```

**To update a single NIC (use UUID from step 4):**

```bash
# Update firmware for a single NIC
./nicctl/bin/nicctl update firmware -i ../firmware/ainic_fw_salina.tar -c 42424650-4c32-3532-3230-313235000000 --reset
```

**Important Notes:**

- The firmware update flashes to the **alternate partition** (A→B or B→A)
- The current running firmware remains active until reboot
- Update takes approximately 3-5 minutes per NIC
- This does **not** cause downtime during the update
- The new firmware will only activate after node reboot

---

## Step 6: Reboot Node to Activate New Firmware

After a successful firmware update, you **must reboot the node** to activate the new firmware:

**Alternative (simple reboot without drain):**

```bash
# From the node (as root)
reboot

# Or from local machine
ssh -i ${SSH_KEY} core@${NODE_IP} sudo reboot
```

---

## Step 7: Verify Firmware Update

After the node reboots, verify the new firmware version:

**From the cluster (recommended):**

```bash
oc debug node/${TARGET_NODE} -- chroot /host bash -c "echo '=== AMD Pensando NIC Firmware Versions ==='; for pci in 08:00.2 18:00.2 68:00.2 78:00.2 88:00.2 98:00.2 f8:00.2; do serial=\$(devlink dev info pci/0000:\$pci 2>/dev/null | grep serial_number | awk '{print \$2}'); fw=\$(devlink dev info pci/0000:\$pci 2>/dev/null | grep 'fw.a35_uboota' | awk '{print \$2}'); cpld=\$(devlink dev info pci/0000:\$pci 2>/dev/null | grep 'fw.cpld' | head -1 | awk '{print \$2}'); [ -n \"\$fw\" ] && echo \"PCI \$pci (S/N:\$serial): FW \$fw, CPLD \$cpld\"; done"
```

**Expected output:**

```bash
=== AMD Pensando NIC Firmware Versions ===
PCI 08:00.2 (S/N:FPL25220125): FW 1.117.5-a-56, CPLD 3.8
PCI 18:00.2 (S/N:FPL25220198): FW 1.117.5-a-56, CPLD 3.8
PCI 68:00.2 (S/N:FPL25220357): FW 1.117.5-a-56, CPLD 3.8
PCI 78:00.2 (S/N:FPL252200E6): FW 1.117.5-a-56, CPLD 3.8
PCI 88:00.2 (S/N:FPL252200DF): FW 1.117.5-a-56, CPLD 3.8
PCI 98:00.2 (S/N:FPL252202F5): FW 1.117.5-a-56, CPLD 3.8
PCI f8:00.2 (S/N:FPL252201C3): FW 1.117.5-a-56, CPLD 3.8
```

**From the node (using nicctl):**

```bash
ssh -i ${SSH_KEY} core@${NODE_IP}
sudo -i
cd /root/ainic_bundle_${AINIC_VERSION}/host_sw_pkg

# Check all NICs
./nicctl/bin/nicctl show card --detail | grep "Id\|IPC BDF\|Firmware version"
```

**Quick check with devlink:**

```bash
oc debug node/${TARGET_NODE} -- chroot /host devlink dev info pci/0000:08:00.2 | grep fw.a35_uboota
```

Expected: `fw.a35_uboota 1.117.5-a-56`

---

## Step 8: Update NetworkConfig Driver Version

After firmware is upgraded, update the AMD Network Operator driver version to match:

```bash
# Update the NetworkConfig CR
kubectl patch networkconfig -n openshift-amd-network amd-network --type='json' \
  -p='[{"op": "replace", "path": "/spec/driver/version", "value": "1.117.5-a-56"}]'

# Verify the update
kubectl get networkconfig -n openshift-amd-network amd-network -o jsonpath='{.spec.driver.version}'

# Check that pods are recreating with new driver version
kubectl get pods -n openshift-amd-network -w
```

Also update the config file for future deployments:

```bash
# Update the YAML file
sed -i 's/version: "1.110.1-a-1"/version: "1.117.5-a-56"/' \
  /home/leo8a/Projects/amd-gpu-lab/amd-openshift/openshift-reference/vendor/amd/network-operator/06_amd-networkconfig.yaml

# Verify change
grep 'version:' /home/leo8a/Projects/amd-gpu-lab/amd-openshift/openshift-reference/vendor/amd/network-operator/06_amd-networkconfig.yaml
```

---

## OpenShift Considerations

After updating NIC firmware on OpenShift nodes:

1. **Driver compatibility:** Ensure the AMD Network Operator driver version matches the new firmware version
2. **Node labeller:** Will automatically work once driver version matches firmware
3. **Pod restarts:** Driver and node-labeller pods will restart when NetworkConfig is updated
4. **Verification:** Check that node-labeller pod is running without CrashLoopBackOff

```bash
# Check node-labeller status
kubectl get pods -n openshift-amd-network -l app.kubernetes.io/name=node-labeller

# Check logs
kubectl logs -n openshift-amd-network -l app.kubernetes.io/name=node-labeller --tail=50
```

---

## Summary

1. ✅ **Step 0:** Set environment variables
2. ✅ **Step 1:** Check current firmware version (using devlink - no nicctl needed yet)
3. ✅ **Step 2:** SCP firmware bundle to node
4. ✅ **Step 3:** Extract bundle and host software (this provides nicctl)
5. ✅ **Step 4:** Check NIC info with nicctl (now available)
6. ✅ **Step 5:** Update firmware on all NICs (~25 min for 7 NICs)
7. ✅ **Step 6:** Drain node (if OpenShift) and reboot
8. ✅ **Step 7:** Verify firmware version after reboot
9. ✅ **Step 8:** Update NetworkConfig driver version to match firmware

**Key Points:**

- **nicctl is inside the firmware bundle** - copy and extract first!
- Use **UUID**, not PCI address, for selective updates
- Firmware flashes to alternate partition (no downtime during update)
- **Node reboot required** to activate new firmware
- **Driver version must match firmware version** to avoid IPC protocol errors
- Card reset will fail after update (expected - use node reboot instead)
