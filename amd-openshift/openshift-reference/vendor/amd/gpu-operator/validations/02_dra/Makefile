# DRA (Dynamic Resource Allocation) Validation
# Reference: https://instinct.docs.amd.com/projects/gpu-operator/en/latest/dra/index.html

MAKEFLAGS += --no-print-directory

NAMESPACE ?= openshift-amd-gpu
TIMEOUT   ?= 120s

# ───────────────────────────────────────────────────────────────────────────────
# Default Target
# ───────────────────────────────────────────────────────────────────────────────

default: help


# ───────────────────────────────────────────────────────────────────────────────
# Setup
# ───────────────────────────────────────────────────────────────────────────────

.PHONY: enable-dra
enable-dra:
	@oc patch deviceconfig amdgpu-driver-install -n $(NAMESPACE) --type merge \
	  --patch-file 00_deviceconfig-dra-patch.yaml
	@echo ""
	@echo "Waiting for DRA driver DaemonSet to be created..."
	@for i in $$(seq 1 60); do \
	  oc get daemonset/amdgpu-driver-install-dra-driver -n $(NAMESPACE) >/dev/null 2>&1 && break; \
	  sleep 2; \
	done
	@echo "Waiting for DRA driver rollout..."
	@oc rollout status daemonset/amdgpu-driver-install-dra-driver -n $(NAMESPACE) --timeout=$(TIMEOUT)

# Usage: $(call wait-for-job,<job-name>)
# Waits for a job to complete or fail, then checks the result.
# Cannot use multiple --for flags (they are ANDed), so we race two waits.
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

.PHONY: full-gpu
full-gpu: enable-dra ## Run 00_full-gpu test
	@echo "" ; echo "Running full-gpu test..."
	@oc apply -k 00_full-gpu/
	$(call wait-for-job,dra-full-gpu-test)

.PHONY: partitioned-gpu
partitioned-gpu: enable-dra ## Run 01_partitioned-gpu test
	@echo "" ; echo "Running partitioned-gpu test..."
	@oc apply -k 01_partitioned-gpu/
	$(call wait-for-job,dra-partitioned-gpu-test)


# ───────────────────────────────────────────────────────────────────────────────
# Cleanup
# ───────────────────────────────────────────────────────────────────────────────

##@ Cleanup

.PHONY: cleanup
cleanup: ## Delete all test resources and restore Device Plugin mode
	@oc delete -k 00_full-gpu/ --ignore-not-found
	@oc delete -k 01_partitioned-gpu/ --ignore-not-found
	@oc apply -f ../../07_amd-deviceconfig.yaml


##@ Help

.PHONY: help
help: ## Display available targets
	@awk 'BEGIN {printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5); } /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-30s\033[0m %s\n", $$1, substr($$0, index($$0, $$3)); }' $(MAKEFILE_LIST)
	@echo ""
