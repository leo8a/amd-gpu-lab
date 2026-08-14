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
	  oc logs job/$(1) -n $(NAMESPACE); echo ; echo "✓ $(1) PASSED" ; exit 0; \
	else \
	  oc logs job/$(1) -n $(NAMESPACE); echo ; echo "✗ $(1) FAILED" ; exit 1; \
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

.PHONY: multi-node-cpu
multi-node-cpu: ## Run 01_multi-node CPU-to-CPU RDMA bandwidth test (ib_write_bw)
	@echo "" ; echo "Running multi-node CPU RDMA bandwidth test..."
	@oc apply -k 01_multi-node-cpu/
	@oc wait pod/rdma-server-cpu -n $(NAMESPACE) --for=condition=ready --timeout=$(TIMEOUT)
	$(call wait-for-job,rdma-client-cpu)

.PHONY: multi-node-gdr
multi-node-gdr: ## Run 03_multi-node-gdr GPU-to-GPU RDMA bandwidth test (GDR, requires amd-tools:gdr image)
	@echo "" ; echo "Running multi-node GDR bandwidth test..."
	@oc apply -k 03_multi-node-gdr/
	@oc wait pod/rdma-server-gdr -n $(NAMESPACE) --for=condition=ready --timeout=$(TIMEOUT)
	$(call wait-for-job,rdma-client-gdr)

DRA_PATCH := ../../../gpu-operator/validations/02_dra/00_deviceconfig-dra-patch.yaml
DRANET_MANIFEST := https://raw.githubusercontent.com/kubernetes-sigs/dranet/refs/heads/main/install.yaml

.PHONY: multi-node-cpu-dra
multi-node-cpu-dra: ## Run 02_multi-node-cpu-dra CPU test with DRA NIC pinning (ionic_0, experimental)
	@echo "" ; echo "Running multi-node CPU-DRA bandwidth test..."
	@echo "--- prerequisites: installing DRANET ---"
	@kubectl apply -f $(DRANET_MANIFEST) 2>/dev/null || true
	@oc adm policy add-scc-to-user privileged -z dranet -n kube-system 2>/dev/null || true
	@echo "--- waiting for DRANET ---"
	@sleep 15
	@oc wait pods -n kube-system -l app=dranet --for=condition=ready --timeout=$(TIMEOUT)
	@echo "--- deploying test ---"
	@oc apply -k 02_multi-node-cpu-dra/
	@oc wait pod/rdma-server-cpu-dra -n $(NAMESPACE) --for=condition=ready --timeout=$(TIMEOUT)
	$(call wait-for-job,rdma-client-cpu-dra)

.PHONY: multi-node-gdr-dra
multi-node-gdr-dra: ## Run 04_multi-node-gdr-dra GDR test with DRA PCIe root alignment (experimental)
	@echo "" ; echo "Running multi-node GDR-DRA bandwidth test..."
	@echo "--- prerequisites: enabling GPU DRA driver ---"
	@oc patch deviceconfig amdgpu-driver-install -n openshift-amd-gpu --type merge -p "$$(cat $(DRA_PATCH))"
	@echo "--- prerequisites: installing DRANET ---"
	@kubectl apply -f $(DRANET_MANIFEST) 2>/dev/null || true
	@oc adm policy add-scc-to-user privileged -z dranet -n kube-system 2>/dev/null || true
	@echo "--- waiting for DRA drivers ---"
	@sleep 15
	@oc wait pods -n openshift-amd-gpu -l daemonset-name=amdgpu-driver-install-dra-driver --for=condition=ready --timeout=$(TIMEOUT)
	@oc wait pods -n kube-system -l app=dranet --for=condition=ready --timeout=$(TIMEOUT)
	@echo "--- deploying test ---"
	@oc apply -k 04_multi-node-gdr-dra/
	@oc wait pod/rdma-server-gdr-dra -n $(NAMESPACE) --for=condition=ready --timeout=$(TIMEOUT)
	$(call wait-for-job,rdma-client-gdr-dra)


# ───────────────────────────────────────────────────────────────────────────────
# Cleanup
# ───────────────────────────────────────────────────────────────────────────────

##@ Cleanup

.PHONY: cleanup
cleanup: ## Delete all test resources
	@oc delete -k 00_single-pod/ --ignore-not-found
	@oc delete -k 01_multi-node-cpu/ --ignore-not-found
	@oc delete -k 02_multi-node-cpu-dra/ --ignore-not-found
	@oc delete -k 03_multi-node-gdr/ --ignore-not-found
	@oc delete -k 04_multi-node-gdr-dra/ --ignore-not-found
	@echo "Restoring GPU device plugin (disabling DRA)..."
	@oc apply -f ../../../gpu-operator/07_amd-deviceconfig.yaml 2>/dev/null || true
	@echo "Removing DRANET..."
	@kubectl delete -f https://raw.githubusercontent.com/kubernetes-sigs/dranet/refs/heads/main/install.yaml --ignore-not-found 2>/dev/null || true
	@oc adm policy remove-scc-from-user privileged -z dranet -n kube-system 2>/dev/null || true


##@ Help

.PHONY: help
help: ## Display available targets
	@awk 'BEGIN {printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5); } /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-30s\033[0m %s\n", $$1, substr($$0, index($$0, $$3)); }' $(MAKEFILE_LIST)
	@echo ""
