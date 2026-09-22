# NIC Prerequisites for ib_write_bw Test

The `ib_write_bw` test requires PFC/DCQCN configured on both NIC and switch (end-to-end). These settings **do not persist across reboots** — re-apply after every reboot or use NIC personas for persistence.

All commands run via `nicctl` inside the `node-labeller` pod:

```bash
NL_POD=$(oc get pods -n openshift-amd-network -l app.kubernetes.io/name=node-labeller \
  --field-selector spec.nodeName=<node> -o jsonpath='{.items[0].metadata.name}')

oc exec -n openshift-amd-network $NL_POD -c node-labeller-container -- /usr/sbin/nicctl <command>
```

Or via `oc debug` with the host-installed binary:

```bash
oc debug node/<node> -- chroot /host /root/nicctl <command>
```

## 1. Disable Auto-Negotiation

Required when the switch does not support AN. Without this, ports stay in `AN_WAIT_HCD` / `DOWN`.

```bash
nicctl update port -p <port-uuid> --auto-neg disable
```

## 2. PFC + QoS (Standard Priority 3)

Per-port configuration matching the AMD Benchmarking Guide (UG1813) defaults.

```bash
# Enable PFC with pause frames
nicctl update port -p <port-uuid> --pause-type pfc --rx-pause enable --tx-pause enable

# DSCP-to-priority mappings
nicctl update qos dscp-to-priority --dscp 24 --priority 3    # RoCEv2 data → lossless Q3
nicctl update qos dscp-to-priority --dscp 46 --priority 6    # CNP/CTS → strict Q6

# Enable no-drop for priority 3
nicctl update qos pfc --priority 3 --no-drop enable

# Scheduling: 99% to Q3, 1% to Q0, strict for Q6
nicctl update qos scheduling --priority 3,0,6 --dwrr 99,1,0 --rate-limit 0,0,10
```

**Apply per port, one UUID at a time.** Despite the `--help` text advertising `-p <uuid1,uuid2,...>`, the `nicctl update qos` subcommands reject a comma-separated port list with `ERROR - Invalid UUID`. Loop over each port UUID individually:

```bash
for p in $(nicctl show port | awk '/^Port :/{print $3}'); do
  nicctl update qos dscp-to-priority -p "$p" --dscp 24 --priority 3
  nicctl update qos dscp-to-priority -p "$p" --dscp 46 --priority 6
  nicctl update qos pfc -p "$p" --priority 3 --no-drop enable
  nicctl update qos scheduling -p "$p" --priority 3,0,6 --dwrr 99,1,0 --rate-limit 0,0,10
done
```

`nicctl update dcqcn` (see below) *does* accept a single `-r <roce-device>` per call; loop over `ionic_0`–`ionic_7`.

## 3. DCQCN

Per RDMA device (`ionic_0`–`ionic_7`).

```bash
nicctl update dcqcn -r <rdma-dev> -i 1 \
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

## 4. Switch Configuration

The switch must also have PFC enabled on priority 3 for the connected ports. Without end-to-end PFC, `ib_write_bw` will fail with `IBV_WC_RETRY_EXC_ERR` due to packet drops.

For switch-side configuration examples, see the [AMD RoCE Network Configuration Guide](https://instinct.docs.amd.com/projects/cluster-documentation/latest/how-to/roce-network-config.html).

## Verification

```bash
nicctl show port                  # Operational status: UP, auto-neg: disabled
nicctl show qos                   # PFC priority 3 no-drop enabled, DSCP 24→Q3, 46→Q6
nicctl show dcqcn                 # DCQCN profile 1 enabled on each RDMA device
```

## Notes

**RDMA CM (`-R`) not supported.** The `ib_write_bw -R` flag (RDMA CM mode) fails on Pollara 400 with error 262. Use TCP socket exchange instead (perftest default, no `-R`). This matches the AMD Benchmarking Guide (UG1813) examples.

**Traffic class vs TOS.** The perftest `-T`/`--tos` flag sets the TOS byte, NOT the DSCP value. Use `--tclass 96` for DSCP 24 (96 = 24 << 2). The `-T` flag is only relevant with `-R` mode.

**MTU.** The NIC default MTU is 9216. The AMD Benchmarking Guide recommends 9K on interfaces and switches for optimal performance.

**DCQCN "Initialization error" on VF LIFs is benign.** If a NIC has an SR-IOV VF reserved (e.g. `eth0_vf0`, MAC one above the PF), `nicctl show dcqcn` lists a second LIF per NIC (`44000070-…`) with `Status: Initialization error` and `ROCE device: -`. This is expected for a `down/down` VF with no RoCE device bound — DCQCN only initializes on the PF RoCE devices (`ionic_0`–`ionic_7`, LIF `43000070-…`). It does not affect RDMA/RCCL tests, which use the PF NICs.

This VF reservation lives in the **NIC device config on the card itself** — it is independent of the OpenShift SR-IOV Network Operator. Removing that operator does **not** clear it. Symptoms of a reserved VF: `nicctl show lif` shows `eth0_vf0`, `cat /sys/class/net/<pf>/device/sriov_totalvfs` returns `1` (vs. the file being absent when no VF is reserved), and the PF netdev is named `enoXXXXnp0` (representor-style) instead of `enoXXXX`. Note `nicctl show card profile` can still report `default` even when a stale VF is reserved, so check `sriov_totalvfs`/`show lif` rather than trusting the profile name alone.

To clear it and make nodes symmetric, re-apply the default card profile with `nicctl update card profile … --profile default` (see `update-ai-nic-profile.md`; firmware A/B must match first), then **reboot the node**. PFC/QoS/DCQCN do not persist across reboots — re-apply §2–§3 afterwards.
