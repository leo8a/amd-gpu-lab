#!/usr/bin/env bash
set -euo pipefail

STAGE_NUM="${1:?Usage: run-gpu-validation.sh <0|1>}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GPU_NAMESPACE="${GPU_NAMESPACE:-openshift-amd-gpu}"
VALIDATIONS_DIR="${VALIDATIONS_DIR:-${REPO_ROOT}/vendor/amd/gpu-operator/validations}"
DRA_DIR="${VALIDATIONS_DIR}/02_dra"
LOG_DIR="${LOG_DIR:-/tmp/validation-logs}"

declare -A STAGE_DIRS=(
  [0]="00_full-gpu"
  [1]="01_partitioned-gpu"
)

declare -A STAGE_JOBS=(
  [0]="dra-full-gpu-test"
  [1]="dra-partitioned-gpu-test"
)

STAGE_DIR="${DRA_DIR}/${STAGE_DIRS[$STAGE_NUM]}"
STAGE_LOG_DIR="${LOG_DIR}/dra-stage-${STAGE_NUM}"
mkdir -p "$STAGE_LOG_DIR"

group()    { if [[ -n "${GITHUB_ACTIONS:-}" ]]; then echo "::group::$1"; else echo "--- $1 ---"; fi; }
endgroup() { if [[ -n "${GITHUB_ACTIONS:-}" ]]; then echo "::endgroup::"; fi; }

# --- Log capture ---
capture_logs() {
  group "Capturing logs for DRA stage $STAGE_NUM"
  JOB_NAME="${STAGE_JOBS[$STAGE_NUM]}"
  for pod in $(oc get pods -n "$GPU_NAMESPACE" -l "job-name=$JOB_NAME" -o name 2>/dev/null); do
    timeout 10 oc logs -n "$GPU_NAMESPACE" "$pod" --all-containers=true --tail=200 \
      > "$STAGE_LOG_DIR/$(basename "$pod").log" 2>&1 || true
  done
  oc get events -n "$GPU_NAMESPACE" --sort-by='.lastTimestamp' \
    > "$STAGE_LOG_DIR/events.log" 2>&1 || true
  oc get resourceslices -o wide \
    > "$STAGE_LOG_DIR/resourceslices.log" 2>&1 || true
  endgroup
}

# --- Cleanup (always runs) ---
cleanup() {
  local exit_code=$?
  group "Cleanup DRA stage $STAGE_NUM"
  capture_logs
  oc delete -k "$STAGE_DIR" --ignore-not-found=true --timeout=60s 2>/dev/null || true
  endgroup
  exit "$exit_code"
}
trap cleanup EXIT

# --- Apply ---
group "Apply DRA stage $STAGE_NUM: ${STAGE_DIRS[$STAGE_NUM]}"
oc apply -k "$STAGE_DIR"
endgroup

# --- Wait + Verify ---
group "Verify DRA stage $STAGE_NUM"
JOB_NAME="${STAGE_JOBS[$STAGE_NUM]}"

oc wait --for=condition=complete --timeout=120s "job/$JOB_NAME" -n "$GPU_NAMESPACE"

LOGS=$(oc logs -n "$GPU_NAMESPACE" "job/$JOB_NAME")
echo "$LOGS"
if echo "$LOGS" | grep -q "=== PASS ==="; then
  echo "PASS: DRA ${STAGE_DIRS[$STAGE_NUM]} validation passed"
else
  echo "FAIL: DRA ${STAGE_DIRS[$STAGE_NUM]} validation failed"
  exit 1
fi
endgroup

echo "DRA stage $STAGE_NUM completed successfully"
