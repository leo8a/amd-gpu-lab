# Cluster Validation
# Validates RDMA connectivity, GPU performance, and network infrastructure across multiple nodes.
# Uses Kubeflow MPI Operator for distributed RCCL tests.

MAKEFLAGS += --no-print-directory

NAMESPACE ?= default
TIMEOUT   ?= 600s

# ───────────────────────────────────────────────────────────────────────────────
# Default Target
# ───────────────────────────────────────────────────────────────────────────────

default: help

# ───────────────────────────────────────────────────────────────────────────────
# Deploy / Teardown
# ───────────────────────────────────────────────────────────────────────────────

##@ Deploy

.PHONY: deploy
deploy: ## Deploy the cluster validation framework (MPI Operator, CronJob, ConfigMaps)
	@echo "" ; echo "Deploying cluster validation framework..."
	@oc apply --server-side -k .
	@echo "Syncing Docker Hub pull secret to mpi-operator namespace..."
	@oc get secret dockerhub-pull-secret -n mpi-operator >/dev/null 2>&1 || \
		oc get secret pull-secret -n openshift-config -o jsonpath='{.data.\.dockerconfigjson}' \
		| base64 -d \
		| oc create secret docker-registry dockerhub-pull-secret -n mpi-operator --from-file=.dockerconfigjson=/dev/stdin
	@oc wait deployment/mpi-operator -n mpi-operator --for=condition=available --timeout=$(TIMEOUT)
	@echo "✓ Cluster validation framework deployed"

.PHONY: teardown
teardown: ## Remove all cluster validation resources and clean node labels
	@echo "" ; echo "Tearing down cluster validation framework..."
	@oc delete job cluster-validation-manual --ignore-not-found
	@oc delete -k . --ignore-not-found
	@oc label nodes --all amd.com/cluster-validation-status- 2>/dev/null || true
	@oc label nodes --all amd.com/cluster-validation-candidate- 2>/dev/null || true
	@echo "✓ Cleanup complete"

# ───────────────────────────────────────────────────────────────────────────────
# Run
# ───────────────────────────────────────────────────────────────────────────────

##@ Run

.PHONY: run
run: ## Trigger a manual validation run (cleans stale labels first)
	@echo "" ; echo "Triggering manual cluster validation..."
	@oc label nodes --all amd.com/cluster-validation-status- 2>/dev/null || true
	@oc label nodes --all amd.com/cluster-validation-candidate- 2>/dev/null || true
	@oc annotate nodes --all amd.com/cluster-validation-last-run-timestamp- 2>/dev/null || true
	@oc delete job cluster-validation-manual --ignore-not-found
	@oc create job --from=cronjob/cluster-validation-cron-job cluster-validation-manual
	@echo "Waiting for job pod to start..."
	@oc wait --for=condition=Ready pod -l job-name=cluster-validation-manual --timeout=$(TIMEOUT)
	@echo "Following logs (Ctrl+C to detach)..."
	@oc logs -f job/cluster-validation-manual -c submit-mpijob

.PHONY: status
status: ## Check validation results (node labels, job status)
	@echo "" ; echo "=== Node Validation Labels ==="
	@oc get nodes -o custom-columns='NODE:.metadata.name,STATUS:.metadata.labels.amd\.com/cluster-validation-status,CANDIDATE:.metadata.labels.amd\.com/cluster-validation-candidate'
	@echo "" ; echo "=== CronJob ==="
	@oc get cronjob cluster-validation-cron-job 2>/dev/null || echo "(not deployed)"
	@echo "" ; echo "=== Jobs ==="
	@oc get jobs -l amd.com/cluster-validation-created=true 2>/dev/null || true
	@oc get job cluster-validation-manual 2>/dev/null || true

.PHONY: logs
logs: ## Show logs from the most recent validation run
	@oc logs job/cluster-validation-manual -c submit-mpijob 2>/dev/null || \
	 oc logs "$$(oc get jobs --sort-by=.metadata.creationTimestamp -o name | grep cluster-validation | tail -1)" -c submit-mpijob 2>/dev/null || \
	 echo "No validation job found"


##@ Help

.PHONY: help
help: ## Display available targets
	@awk 'BEGIN {printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5); } /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-30s\033[0m %s\n", $$1, substr($$0, index($$0, $$3)); }' $(MAKEFILE_LIST)
	@echo ""
