# RDMA Validation
# Validates RDMA device visibility and multi-node connectivity with AMD Pensando AI NICs.

MAKEFLAGS += --no-print-directory

NAMESPACE ?= openshift-amd-network
TIMEOUT   ?= 180s

# ───────────────────────────────────────────────────────────────────────────────
# Default Target
# ───────────────────────────────────────────────────────────────────────────────

default: help

# Usage: $(call wait-for-job,<job-name>)
define wait-for-job
	@oc wait job/$(1) -n $(NAMESPACE) --for=condition=complete --timeout=$(TIMEOUT) 2>/dev/null & \
	oc wait job/$(1) -n $(NAMESPACE) --for=condition=failed --timeout=$(TIMEOUT) 2>/dev/null & \
	wait -n; \
	if [ "$$(oc get job/$(1) -n $(NAMESPACE) -o jsonpath='{.status.succeeded}')" = "1" ]; then \
	  echo "✓ $(1) PASSED"; \
	else \
	  echo "✗ $(1) FAILED"; oc logs job/$(1) -n $(NAMESPACE); exit 1; \
	fi
endef


# ───────────────────────────────────────────────────────────────────────────────
# Tests
# ───────────────────────────────────────────────────────────────────────────────

##@ Tests

.PHONY: single-pod
single-pod: ## Run 00_single-pod RDMA device check
	@echo "" ; echo "Running single-pod RDMA test..."
	@oc apply -k 00_single-pod/
	$(call wait-for-job,rdma-single-pod-test)

.PHONY: multi-node
multi-node: ## Run 01_multi-node RDMA bandwidth test (ib_write_bw)
	@echo "" ; echo "Running multi-node RDMA bandwidth test..."
	@oc apply -k 01_multi-node/
	@oc wait pod/rdma-server -n $(NAMESPACE) --for=condition=ready --timeout=$(TIMEOUT)
	$(call wait-for-job,rdma-multi-node-test)


# ───────────────────────────────────────────────────────────────────────────────
# Cleanup
# ───────────────────────────────────────────────────────────────────────────────

##@ Cleanup

.PHONY: cleanup
cleanup: ## Delete all test resources
	@oc delete -k 00_single-pod/ --ignore-not-found
	@oc delete -k 01_multi-node/ --ignore-not-found


##@ Help

.PHONY: help
help: ## Display available targets
	@awk 'BEGIN {printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5); } /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-30s\033[0m %s\n", $$1, substr($$0, index($$0, $$3)); }' $(MAKEFILE_LIST)
	@echo ""
