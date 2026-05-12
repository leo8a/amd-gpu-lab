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

### Running nicctl without the ainic_bundle on the node

If the `ainic_bundle` is not present on the host, `nicctl` is available inside
the `openshift-amd-network` namespace pods (`node-labeller` and `metrics-exporter`
containers) at `/usr/sbin/nicctl`.

```bash
# List port status
oc exec -n openshift-amd-network <node-labeller-pod> -c node-labeller-container \
  -- /usr/sbin/nicctl show port

# Disable auto-negotiation on a port
oc exec -n openshift-amd-network <node-labeller-pod> -c node-labeller-container \
  -- /usr/sbin/nicctl update port -p <port-uuid> --auto-neg disable
```

### Verifying L2 connectivity between nodes

After bringing ports UP, verify L2 with temporary IPs and arping:

```bash
# On node A (via oc debug)
oc debug node/<node-a> -- chroot /host bash -c 'ip addr add 10.99.99.1/24 dev <ionic-iface>'

# On node B — arping node A
oc debug node/<node-b> -- chroot /host bash -c \
  'ip addr add 10.99.99.2/24 dev <ionic-iface>; arping -c 3 -I <ionic-iface> 10.99.99.1'

# Cleanup
oc debug node/<node-a> -- chroot /host bash -c 'ip addr del 10.99.99.1/24 dev <ionic-iface>'
oc debug node/<node-b> -- chroot /host bash -c 'ip addr del 10.99.99.2/24 dev <ionic-iface>'
```

To find ionic interfaces: `ls /sys/class/net/ | grep enp` and check the driver
symlink at `/sys/class/net/<iface>/device/driver` points to `ionic`.

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

### Switch cabling status (2026-05-06)

IT only cabled **one port on smc6216gpu** (`enp25s0np0`) to the backend switch.
smc6217gpu was fully connected (all 7 ports). The NAD had to pin pods to the
working interface on each node.

**smc6217gpu &rarr; smc6216gpu** (any src reaches smc6216gpu only via `enp25s0np0`):

| src \ dst           | .1 (9s0) | .2 (25s0) | .3 (105s0) | .4 (121s0) | .5 (137s0) | .6 (153s0) | .7 (249s0) |
| ------------------- | -------- | --------- | ---------- | ---------- | ---------- | ---------- | ---------- |
| .11 (9s0np0)        | --       | OK        | --         | --         | --         | --         | --         |
| .12 (25s0np0)       | --       | OK        | --         | --         | --         | --         | --         |
| .13 (105s0np0)      | --       | OK        | --         | --         | --         | --         | --         |
| .14 (121s0np0)      | --       | OK        | --         | --         | --         | --         | --         |
| .15 (137s0np0)      | --       | OK        | --         | --         | --         | --         | --         |
| .16 (153s0np0)      | --       | OK        | --         | --         | --         | --         | --         |
| .17 (249s0np0)      | --       | OK        | --         | --         | --         | --         | --         |

**smc6216gpu &rarr; smc6217gpu** (only `enp25s0np0` can reach any dst):

| src \ dst           | .11 (9s0) | .12 (25s0) | .13 (105s0) | .14 (121s0) | .15 (137s0) | .16 (153s0) | .17 (249s0) |
| ------------------- | --------- | ---------- | ----------- | ----------- | ----------- | ----------- | ----------- |
| .1 (9s0np0)         | --        | --         | --          | --          | --          | --          | --          |
| .2 (25s0np0)        | OK        | OK         | OK          | OK          | OK          | OK          | OK          |
| .3 (105s0np0)       | --        | --         | --          | --          | --          | --          | --          |
| .4 (121s0np0)       | --        | --         | --          | --          | --          | --          | --          |
| .5 (137s0np0)       | --        | --         | --          | --          | --          | --          | --          |
| .6 (153s0np0)       | --        | --         | --          | --          | --          | --          | --          |
| .7 (249s0np0)       | --        | --         | --          | --          | --          | --          | --          |

### Switch cabling status (2026-05-11)

IT fully cabled all 7 ports on **both nodes**. All 49 pairs (7x7) pass in
both directions — full multi-rail RDMA is available.

**smc6217gpu &rarr; smc6216gpu** (all OK):

| src \ dst           | .1 (9s0) | .2 (25s0) | .3 (105s0) | .4 (121s0) | .5 (137s0) | .6 (153s0) | .7 (249s0) |
| ------------------- | -------- | --------- | ---------- | ---------- | ---------- | ---------- | ---------- |
| .11 (9s0np0)        | OK       | OK        | OK         | OK         | OK         | OK         | OK         |
| .12 (25s0np0)       | OK       | OK        | OK         | OK         | OK         | OK         | OK         |
| .13 (105s0np0)      | OK       | OK        | OK         | OK         | OK         | OK         | OK         |
| .14 (121s0np0)      | OK       | OK        | OK         | OK         | OK         | OK         | OK         |
| .15 (137s0np0)      | OK       | OK        | OK         | OK         | OK         | OK         | OK         |
| .16 (153s0np0)      | OK       | OK        | OK         | OK         | OK         | OK         | OK         |
| .17 (249s0np0)      | OK       | OK        | OK         | OK         | OK         | OK         | OK         |

**smc6216gpu &rarr; smc6217gpu** (all OK):

| src \ dst           | .11 (9s0) | .12 (25s0) | .13 (105s0) | .14 (121s0) | .15 (137s0) | .16 (153s0) | .17 (249s0) |
| ------------------- | --------- | ---------- | ----------- | ----------- | ----------- | ----------- | ----------- |
| .1 (9s0np0)         | OK        | OK         | OK          | OK          | OK          | OK          | OK          |
| .2 (25s0np0)        | OK        | OK         | OK          | OK          | OK          | OK          | OK          |
| .3 (105s0np0)       | OK        | OK         | OK          | OK          | OK          | OK          | OK          |
| .4 (121s0np0)       | OK        | OK         | OK          | OK          | OK          | OK          | OK          |
| .5 (137s0np0)       | OK        | OK         | OK          | OK          | OK          | OK          | OK          |
| .6 (153s0np0)       | OK        | OK         | OK          | OK          | OK          | OK          | OK          |
| .7 (249s0np0)       | OK        | OK         | OK          | OK          | OK          | OK          | OK          |

> **Takeaway:** Full 7-rail multi-node RDMA is now available. NAD no longer
> needs to pin to a specific interface.
