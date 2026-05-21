# NIC Prerequisites for ib_write_bw Test

The `ib_write_bw` test requires PFC/DCQCN configured on both NIC and switch (end-to-end). These settings **do not persist across reboots** — re-apply after every reboot or use NIC personas for persistence.

All commands run via `nicctl` inside the `node-labeller` pod:

```bash
NL_POD=$(oc get pods -n openshift-amd-network -l app.kubernetes.io/name=node-labeller \
  --field-selector spec.nodeName=<node> -o jsonpath='{.items[0].metadata.name}')

oc exec -n openshift-amd-network $NL_POD -c node-labeller-container -- /usr/sbin/nicctl <command>
```

## 1. Disable Auto-Negotiation

Required when the switch does not support AN. Without this, ports stay in `AN_WAIT_HCD` / `DOWN`.

```bash
nicctl update port -p <port-uuid> --auto-neg disable
```

## 2. PFC + QoS (Option B — Standard Priority 3)

Per-port configuration matching the AMD Benchmarking Guide defaults.

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

## 3. DCQCN

Per RDMA device (`ionic_0`–`ionic_6`).

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

The switch must also have PFC enabled on priority 3 for the connected ports. Without end-to-end PFC, `ib_write_bw` will fail with `IBV_WC_RETRY_EXC_ERR` (error 262) due to packet drops.

## Verification

```bash
nicctl show port                  # Operational status: UP
nicctl show qos                   # PFC priority 3 no-drop enabled
nicctl show dcqcn                 # DCQCN parameters applied
```
