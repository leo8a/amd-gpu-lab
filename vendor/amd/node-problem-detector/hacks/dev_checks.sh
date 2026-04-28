#!/bin/bash
# Quick reference commands for validating NPD on OpenShift with AMD GPUs.

NS="node-problem-detector"
NPD_POD=$(oc -n "$NS" get pods -o jsonpath='{.items[0].metadata.name}')

# --- Deployment health ---

# DaemonSet rollout status
oc -n "$NS" rollout status daemonset/node-problem-detector

# List all NPD pods and their node placement
oc -n "$NS" get pods -o wide

# Pod logs (last 30 lines)
oc -n "$NS" logs daemonset/node-problem-detector --tail=30

# --- Node conditions set by NPD ---

# Show only AMD GPU conditions across all nodes
oc get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .status.conditions[?(@.type)]}{" "}{.type}: {.status} ({.reason}) - {.message}{"\n"}{end}{"\n"}{end}' | grep -B1 -i "amdgpu"

# --- amdgpuhealth binary inspection ---

# Check available subcommands
oc -n "$NS" exec "$NPD_POD" -- /var/lib/amd-metrics-exporter/amdgpuhealth --help

# Check available flags for a subcommand
oc -n "$NS" exec "$NPD_POD" -- /var/lib/amd-metrics-exporter/amdgpuhealth query counter-metric --help
oc -n "$NS" exec "$NPD_POD" -- /var/lib/amd-metrics-exporter/amdgpuhealth query gauge-metric --help

# Run a health check manually and inspect exit code
oc -n "$NS" exec "$NPD_POD" -- /var/lib/amd-metrics-exporter/amdgpuhealth query counter-metric -m=GPU_ECC_UNCORRECT_UMC -t=1
echo "Exit code: $?"

# --- Inband-RAS errors ---

GPU_NS="openshift-amd-gpu"
EXPORTER_POD=$(oc -n "$GPU_NS" get pods -l app.kubernetes.io/name=metrics-exporter -o jsonpath='{.items[0].metadata.name}')

# Query the inband-RAS endpoint directly from the metrics exporter
oc -n "$GPU_NS" exec "$EXPORTER_POD" -- curl -s http://localhost:5000/inbandraserrors

# Run inband-ras-errors check manually from an NPD pod (exit 0=healthy, 1=problem, 2=unknown)
oc -n "$NS" exec "$NPD_POD" -- /var/lib/amd-metrics-exporter/amdgpuhealth query inband-ras-errors -s=CPER_SEVERITY_FATAL --afid=30 -t=0
echo "Exit code: $?"

oc -n "$NS" exec "$NPD_POD" -- /var/lib/amd-metrics-exporter/amdgpuhealth query inband-ras-errors -s=CPER_SEVERITY_FATAL --afid=25 -t=0
echo "Exit code: $?"

# Check available flags for inband-ras-errors
oc -n "$NS" exec "$NPD_POD" -- /var/lib/amd-metrics-exporter/amdgpuhealth query inband-ras-errors --help

# --- Custom plugin monitor config ---

# View the active config
oc -n "$NS" get configmap node-problem-detector-config -o jsonpath='{.data.custom-plugin-monitor\.json}' | python3 -m json.tool

# --- SCC and RBAC ---

# Verify the SA can use the privileged SCC
oc adm policy who-can use scc privileged | grep npd

# Check ClusterRole permissions
oc describe clusterrole node-problem-detector
