# NIC Diagnostic Logs

Logs collected from AMD Pensando Pollara 400G NICs using `nicctl` from the AI NIC firmware bundle.

## SSH Access to Nodes

```bash
export TARGET_NODE="<hostname>.partner-accelerators.redhat.lab"
export NODE_IP="<node-ip>"
export SSH_KEY="/home/leo8a/Projects/amd-gpu-lab/amd-labs/amd-lab-virt/ssh/id_rsa"
export AINIC_VERSION="1.117.5-a-56"
export NICCTL="/root/ainic_bundle_${AINIC_VERSION}/host_sw_pkg/nicctl/bin/nicctl"

ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no core@${NODE_IP} "sudo ${NICCTL} show port"
```

### Known Nodes

| Hostname   | IP             |
| ---------- | -------------- |
| smc6216gpu | 10.216.91.164  |
| smc6217gpu | 10.216.91.138  |

## Commands

```bash
sudo ${NICCTL} show port                  # → port.log
sudo ${NICCTL} show port transceiver -d   # → transceiver.log
```

## Folder Structure

```yaml
logs/<hostname>-<YYYY-MM-DD>/
├── port.log          # Port spec/status (link state, speed, MAC, PID)
└── transceiver.log   # Transceiver details (vendor, serial, lane diagnostics)
```

## Troubleshooting Notes

### Auto-Negotiation Mismatch (2026-05-04)

**Symptom:** All 14 ports across both nodes stuck in `AN_WAIT_HCD` / `DOWN` state.

**Root cause:** The switch does not have auto-negotiation enabled on its ports.
The NICs default to AN enabled, so they wait indefinitely for the AN handshake.

**Fix:** Disable auto-negotiation on each NIC port:

```bash
sudo ${NICCTL} update port -p <port-uuid> --auto-neg disable
```

After disabling AN, all ports came up immediately at 400G with RS FEC.

#### smc6217gpu (applied 2026-05-04)

```bash
export NODE_IP="10.216.91.138"
export SSH_KEY="/home/leo8a/Projects/amd-gpu-lab/amd-labs/amd-lab-virt/ssh/id_rsa"
export NICCTL="/root/ainic_bundle_1.117.5-a-56/host_sw_pkg/nicctl/bin/nicctl"
export SSH_CMD="ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no core@${NODE_IP}"

# Disable AN on all 7 ports
${SSH_CMD} "sudo ${NICCTL} update port -p 04908136-72a8-4242-4242-000011010000 --auto-neg disable"
${SSH_CMD} "sudo ${NICCTL} update port -p 04908136-7d70-4242-4242-000011010000 --auto-neg disable"
${SSH_CMD} "sudo ${NICCTL} update port -p 04908136-a758-4242-4242-000011010000 --auto-neg disable"
${SSH_CMD} "sudo ${NICCTL} update port -p 04908136-6cc0-4242-4242-000011010000 --auto-neg disable"
${SSH_CMD} "sudo ${NICCTL} update port -p 04908136-6c18-4242-4242-000011010000 --auto-neg disable"
${SSH_CMD} "sudo ${NICCTL} update port -p 04908136-9e28-4242-4242-000011010000 --auto-neg disable"
${SSH_CMD} "sudo ${NICCTL} update port -p 04908136-8178-4242-4242-000011010000 --auto-neg disable"

# Verify all ports are UP
${SSH_CMD} "sudo ${NICCTL} show port" | grep -E "(NIC |Port |Operational status)"
```

#### smc6216gpu (applied 2026-05-04)

```bash
export NODE_IP="10.216.91.164"
export SSH_KEY="/home/leo8a/Projects/amd-gpu-lab/amd-labs/amd-lab-virt/ssh/id_rsa"
export NICCTL="/root/ainic_bundle_1.117.5-a-56/host_sw_pkg/nicctl/bin/nicctl"
export SSH_CMD="ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no core@${NODE_IP}"

# Disable AN on all 7 ports
${SSH_CMD} "sudo ${NICCTL} update port -p 04908136-9960-4242-4242-000011010000 --auto-neg disable"
${SSH_CMD} "sudo ${NICCTL} update port -p 04908136-a878-4242-4242-000011010000 --auto-neg disable"
${SSH_CMD} "sudo ${NICCTL} update port -p 04908136-7068-4242-4242-000011010000 --auto-neg disable"
${SSH_CMD} "sudo ${NICCTL} update port -p 04908136-ae48-4242-4242-000011010000 --auto-neg disable"
${SSH_CMD} "sudo ${NICCTL} update port -p 04908136-6ed0-4242-4242-000011010000 --auto-neg disable"
${SSH_CMD} "sudo ${NICCTL} update port -p 04908136-7278-4242-4242-000011010000 --auto-neg disable"
${SSH_CMD} "sudo ${NICCTL} update port -p 04908136-7308-4242-4242-000011010000 --auto-neg disable"

# Verify all ports are UP
${SSH_CMD} "sudo ${NICCTL} show port" | grep -E "(NIC |Port |Operational status)"
```

> **Note:** This setting is not persistent across NIC reboots. It needs to be
> applied via the NIC profile or re-applied after firmware updates. See
> `docs/update-ai-nic-profile.md` for making this change permanent.
