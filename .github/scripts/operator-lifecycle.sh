#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:?Usage: operator-lifecycle.sh <uninstall|install>}"
NAMESPACE="${NAMESPACE:-openshift-amd-network}"
OPERATOR_DIR="${OPERATOR_DIR:-amd-openshift/openshift-reference/vendor/amd/network-operator}"
LOG_DIR="${LOG_DIR:-/tmp/validation-logs}"

STAGE_LOG_DIR="${LOG_DIR}/${ACTION}-operator"
mkdir -p "$STAGE_LOG_DIR"

group()    { if [[ -n "${GITHUB_ACTIONS:-}" ]]; then echo "::group::$1"; else echo "--- $1 ---"; fi; }
endgroup() { if [[ -n "${GITHUB_ACTIONS:-}" ]]; then echo "::endgroup::"; fi; }

case "$ACTION" in
  uninstall)
    group "Remove NetworkConfig CR"
    oc delete -f "$OPERATOR_DIR/05_amd-networkconfig.yaml" --ignore-not-found=true --timeout=120s
    endgroup

    group "Wait for operator pods to terminate"
    oc wait --for=delete pod -l app.kubernetes.io/managed-by=amd-network-operator -n "$NAMESPACE" --timeout=300s 2>/dev/null || true
    endgroup

    group "Capture pre-uninstall logs"
    for pod in $(oc get pods -n "$NAMESPACE" -o name 2>/dev/null); do
      oc logs -n "$NAMESPACE" "$pod" --all-containers=true \
        > "$STAGE_LOG_DIR/$(basename "$pod").log" 2>&1 || true
    done
    oc get events -n "$NAMESPACE" --sort-by='.lastTimestamp' \
      > "$STAGE_LOG_DIR/events.log" 2>&1 || true
    endgroup

    group "Remove OLM artifacts"
    oc delete -f "$OPERATOR_DIR/02_amd-network-subscription.yaml" --ignore-not-found=true
    CSV=$(oc get csv -n "$NAMESPACE" -o jsonpath='{.items[?(@.spec.displayName=="AMD Network Operator")].metadata.name}' 2>/dev/null || true)
    if [[ -n "$CSV" ]]; then
      echo "Deleting ClusterServiceVersion: $CSV"
      oc delete csv "$CSV" -n "$NAMESPACE" --timeout=60s
    fi
    oc delete -f "$OPERATOR_DIR/01_amd-network-opergroup.yaml" --ignore-not-found=true
    oc delete -f "$OPERATOR_DIR/00_amd-network-catalogsource.yaml" --ignore-not-found=true
    endgroup

    group "Wait for operator namespace to be clean"
    SECONDS=0
    while [[ $SECONDS -lt 120 ]]; do
      POD_COUNT=$(oc get pods -n "$NAMESPACE" --no-headers 2>/dev/null | wc -l)
      if [[ "$POD_COUNT" -eq 0 ]]; then
        echo "Namespace $NAMESPACE is clean"
        break
      fi
      echo "Waiting for $POD_COUNT pod(s) to terminate..."
      sleep 10
    done
    endgroup

    echo "Network operator uninstalled successfully"
    ;;

  install)
    group "Apply operator resources"
    oc apply -k "$OPERATOR_DIR"
    endgroup

    group "Wait for Subscription to resolve"
    SECONDS=0
    while [[ $SECONDS -lt 300 ]]; do
      CSV=$(oc get subscription amd-network-operator -n "$NAMESPACE" -o jsonpath='{.status.installedCSV}' 2>/dev/null || true)
      if [[ -n "$CSV" ]]; then
        echo "CSV resolved: $CSV"
        break
      fi
      echo "Waiting for Subscription to resolve CSV..."
      sleep 10
    done
    if [[ -z "$CSV" ]]; then
      echo "FAIL: Subscription did not resolve a CSV within 5 minutes"
      exit 1
    fi
    endgroup

    group "Wait for CSV to succeed"
    oc wait csv "$CSV" -n "$NAMESPACE" --for=jsonpath='{.status.phase}'=Succeeded --timeout=300s
    endgroup

    group "Wait for operator pods"
    SECONDS=0
    while [[ $SECONDS -lt 300 ]]; do
      READY=$(oc get pods -n "$NAMESPACE" --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
      if [[ "$READY" -ge 1 ]]; then
        echo "Operator pods running: $READY"
        oc get pods -n "$NAMESPACE" -o wide
        break
      fi
      echo "Waiting for operator pods..."
      sleep 10
    done
    endgroup

    group "Verify NetworkConfig CR is accepted"
    oc wait networkconfig amd-network -n "$NAMESPACE" --for=jsonpath='{.status.state}'=ready --timeout=600s 2>/dev/null || {
      echo "WARNING: NetworkConfig status not 'ready', checking pods instead..."
      SECONDS=0
      while [[ $SECONDS -lt 300 ]]; do
        DAEMONSET_READY=$(oc get pods -n "$NAMESPACE" -l app.kubernetes.io/managed-by=amd-network-operator --no-headers 2>/dev/null | grep -c "Running" || true)
        if [[ "$DAEMONSET_READY" -ge 2 ]]; then
          echo "Operator daemonset pods running: $DAEMONSET_READY"
          break
        fi
        echo "Waiting for operator-managed pods ($DAEMONSET_READY running)..."
        sleep 15
      done
    }
    endgroup

    group "Operator status"
    oc get pods -n "$NAMESPACE" -o wide
    oc get networkconfig -n "$NAMESPACE" 2>/dev/null || true
    endgroup

    echo "Network operator installed successfully"
    ;;

  *)
    echo "Unknown action: $ACTION (expected 'uninstall' or 'install')"
    exit 1
    ;;
esac
