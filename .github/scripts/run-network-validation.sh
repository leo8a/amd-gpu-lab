#!/usr/bin/env bash
set -euo pipefail

STAGE_NUM="${1:?Usage: run-network-validation.sh <0-5>}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NAMESPACE="${NAMESPACE:-openshift-amd-network}"
VALIDATIONS_DIR="${VALIDATIONS_DIR:-${REPO_ROOT}/vendor/amd/network-operator/validations}"
LOG_DIR="${LOG_DIR:-/tmp/validation-logs}"

declare -A STAGE_DIRS=(
  [0]="00_cluster-validation"
  [1]="01_basic/00_nic-assignment"
  [2]="02_rdma/00_single-pod"
  [3]="02_rdma/01_multi-node"
  [4]="03_sriov/00_pf1_vf1-profile"
  [5]="03_sriov/01_hnic_pf1_vf8-profile"
)

STAGE_DIR="${VALIDATIONS_DIR}/${STAGE_DIRS[$STAGE_NUM]}"
STAGE_LOG_DIR="${LOG_DIR}/stage-${STAGE_NUM}"
mkdir -p "$STAGE_LOG_DIR"

group()    { if [[ -n "${GITHUB_ACTIONS:-}" ]]; then echo "::group::$1"; else echo "--- $1 ---"; fi; }
endgroup() { if [[ -n "${GITHUB_ACTIONS:-}" ]]; then echo "::endgroup::"; fi; }

# --- Log capture ---
capture_logs() {
  group "Capturing logs for stage $STAGE_NUM"
  for pod in $(oc get pods -n "$NAMESPACE" -o name 2>/dev/null); do
    timeout 10 oc logs -n "$NAMESPACE" "$pod" --all-containers=true --tail=200 \
      > "$STAGE_LOG_DIR/$(basename "$pod").log" 2>&1 || true
  done
  oc get events -n "$NAMESPACE" --sort-by='.lastTimestamp' \
    > "$STAGE_LOG_DIR/events.log" 2>&1 || true
  oc get pods -n "$NAMESPACE" -o wide \
    > "$STAGE_LOG_DIR/pods.log" 2>&1 || true

  if [[ "$STAGE_NUM" == "0" ]]; then
    for pod in $(oc get pods -n default -l amd.com/cluster-validation-created=true -o name 2>/dev/null); do
      timeout 10 oc logs -n default "$pod" --all-containers=true --tail=200 \
        > "$STAGE_LOG_DIR/default-$(basename "$pod").log" 2>&1 || true
    done
    oc get events -n default --sort-by='.lastTimestamp' \
      > "$STAGE_LOG_DIR/default-events.log" 2>&1 || true
  fi
  endgroup
}

# --- Cleanup (always runs) ---
cleanup() {
  local exit_code=$?
  group "Cleanup stage $STAGE_NUM"
  capture_logs

  oc delete -k "$STAGE_DIR" --ignore-not-found=true --timeout=60s 2>/dev/null || true

  if [[ "$STAGE_NUM" == "5" ]]; then
    echo "Restoring original device-plugin ConfigMap (isRdma: true)..."
    oc apply -f "${VALIDATIONS_DIR}/../07_amd-device-plugin-config.yaml" 2>/dev/null || true
    oc delete pods -n "$NAMESPACE" -l app.kubernetes.io/name=device-plugin --ignore-not-found=true 2>/dev/null || true
  fi

  if [[ "$STAGE_NUM" == "0" ]]; then
    oc delete job -l ci-triggered=true -n default --ignore-not-found=true 2>/dev/null || true
    oc delete job -l amd.com/cluster-validation-created=true -n default --ignore-not-found=true 2>/dev/null || true
    oc label nodes --all \
      amd.com/cluster-validation-status- \
      amd.com/cluster-validation-candidate- \
      amd.com/gpu-validation-test- \
      2>/dev/null || true
  fi
  endgroup
  exit "$exit_code"
}
trap cleanup EXIT

# --- Apply ---
group "Apply stage $STAGE_NUM: ${STAGE_DIRS[$STAGE_NUM]}"
if [[ "$STAGE_NUM" == "0" ]]; then
  oc apply --server-side -k "$STAGE_DIR"
else
  oc apply -k "$STAGE_DIR"
fi
endgroup

# --- Wait + Verify ---
group "Verify stage $STAGE_NUM"
case "$STAGE_NUM" in
  0)
    oc wait --for=condition=established crd/mpijobs.kubeflow.org --timeout=180s

    JOB_NAME="cluster-validation-ci-$(date +%s)"
    oc create job "$JOB_NAME" --from=cronjob/cluster-validation-cron-job -n default
    oc label job "$JOB_NAME" -n default ci-triggered=true

    for node in $(oc get nodes -l feature.node.kubernetes.io/amd-nic=true -o name); do
      oc annotate "$node" amd.com/cluster-validation-last-run-timestamp- 2>/dev/null || true
    done

    JOB_POD=$(oc get pods -n default -l job-name="$JOB_NAME" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    echo "Waiting for submit-mpijob container to complete (pod: $JOB_POD)..."
    SECONDS=0
    while [[ $SECONDS -lt 1500 ]]; do
      STATE=$(oc get pod "$JOB_POD" -n default \
        -o jsonpath='{.status.containerStatuses[?(@.name=="submit-mpijob")].state}' 2>/dev/null)
      if echo "$STATE" | grep -q "terminated"; then
        EXIT_CODE=$(oc get pod "$JOB_POD" -n default \
          -o jsonpath='{.status.containerStatuses[?(@.name=="submit-mpijob")].state.terminated.exitCode}' 2>/dev/null)
        echo "submit-mpijob exited with code $EXIT_CODE"
        if [[ "$EXIT_CODE" != "0" ]]; then
          echo "FAIL: Cluster validation job failed"
          oc logs -n default "$JOB_POD" -c submit-mpijob 2>/dev/null || true
          exit 1
        fi
        break
      fi
      sleep 10
    done
    if [[ $SECONDS -ge 1500 ]]; then
      echo "FAIL: Cluster validation job did not complete within 25 minutes"
      oc logs -n default "$JOB_POD" -c submit-mpijob 2>/dev/null || true
      exit 1
    fi

    PASSED_COUNT=$(oc get nodes -l amd.com/cluster-validation-status=passed --no-headers 2>/dev/null | wc -l)
    if [[ "$PASSED_COUNT" -ge 1 ]]; then
      echo "PASS: $PASSED_COUNT node(s) passed cluster validation"
    else
      echo "FAIL: No nodes have cluster-validation-status=passed"
      exit 1
    fi
    ;;

  1)
    oc wait --for=condition=Ready pod/test-amd-nic -n "$NAMESPACE" --timeout=120s
    OUTPUT=$(oc exec -n "$NAMESPACE" test-amd-nic -- ip addr show)
    echo "$OUTPUT"
    if echo "$OUTPUT" | grep -q "net1"; then
      echo "PASS: net1 interface found"
    else
      echo "FAIL: net1 interface not found"
      exit 1
    fi
    ;;

  2)
    oc wait --for=condition=Ready pod/rdma-test -n "$NAMESPACE" --timeout=120s
    oc wait --for=jsonpath='{.status.phase}'=Succeeded pod/rdma-test -n "$NAMESPACE" --timeout=120s

    LOGS=$(oc logs -n "$NAMESPACE" rdma-test)
    echo "$LOGS"
    if echo "$LOGS" | grep -q "RDMA Validation: PASSED"; then
      echo "PASS: RDMA single-pod validation passed"
    else
      echo "FAIL: RDMA validation output not found"
      exit 1
    fi
    ;;

  3)
    NODE_COUNT=$(oc get nodes -l feature.node.kubernetes.io/amd-nic=true --no-headers | wc -l)
    if [[ "$NODE_COUNT" -lt 2 ]]; then
      echo "SKIP: Multi-node RDMA requires 2+ AMD NIC nodes (found $NODE_COUNT)"
      exit 0
    fi

    oc wait --for=condition=Ready pod/rdma-server -n "$NAMESPACE" --timeout=120s
    oc wait --for=condition=Ready pod/rdma-client -n "$NAMESPACE" --timeout=120s
    oc wait --for=jsonpath='{.status.phase}'=Succeeded pod/rdma-client -n "$NAMESPACE" --timeout=180s

    LOGS=$(oc logs -n "$NAMESPACE" rdma-client)
    echo "$LOGS"
    if echo "$LOGS" | grep -q "RDMA Connectivity Test: PASSED"; then
      echo "PASS: RDMA multi-node connectivity passed"
    else
      echo "FAIL: RDMA multi-node connectivity test failed"
      exit 1
    fi
    ;;

  4|5)
    oc wait --for=condition=Ready pod/test-amd-sriov -n "$NAMESPACE" --timeout=300s
    OUTPUT=$(oc exec -n "$NAMESPACE" test-amd-sriov -- ip addr show)
    echo "$OUTPUT"
    if echo "$OUTPUT" | grep -q "net1"; then
      echo "PASS: SR-IOV VF interface (net1) found"
    else
      echo "FAIL: net1 interface not found in SR-IOV pod"
      exit 1
    fi
    ;;

  *)
    echo "Unknown stage: $STAGE_NUM"
    exit 1
    ;;
esac
endgroup

echo "Stage $STAGE_NUM completed successfully"
