# AMD GPU Partitioning via DCM Workflow
# Reference: https://instinct.docs.amd.com/projects/gpu-operator/en/latest/dcm/applying-partition-profiles.html

MAKEFLAGS += --no-print-directory

# =============================================================================
# Configuration
# =============================================================================

# Prompt for NODE_NAME if not provided
# - (AMD Shared Lab) smc6217gpu.partner-accelerators.redhat.lab, smc6216gpu.partner-accelerators.redhat.lab
# - (PerfScale Lab) j42-h01-000-xe9680.rdu3.labs.perfscale.redhat.com

ifndef NODE_NAME
NODE_NAME := $(shell bash -c 'read -p "Enter node name: " node; echo $$node')
endif

NAMESPACE    ?= openshift-amd-gpu
PROFILE_NAME ?= spx-profile-nps1  			# Options: spx-profile-nps1, cpx-profile-{nps1,nps4}, dpx-profile-{nps1,nps2}

# Optimal Pairings, derived from https://instinct.docs.amd.com/projects/amdgpu-docs/en/latest/gpu-partitioning/mi300x/overview.html#b-memory-partitioning-nps
#     - SPX + NPS1: Maximum performance per GPU (single tenant)
#     - CPX + NPS4: Maximum partitioning (8 GPUs, best for multi-tenant)
#     - DPX + NPS2: Balanced locality

# Export all variables for scripts
export NODE_NAME
export PROFILE_NAME
export NAMESPACE


# ───────────────────────────────────────────────────────────────────────────────
# Default Target
# ───────────────────────────────────────────────────────────────────────────────

default: help


# ───────────────────────────────────────────────────────────────────────────────
# Main Workflow Targets
# ───────────────────────────────────────────────────────────────────────────────

##@ Workflow Steps

.PHONY: all
all: cleanup tolerations deploy-dcm taint label verify untaint ## Run complete workflow (steps 1-6)

.PHONY: tolerations
tolerations: ## Step 1: Add tolerations to prevent system pod eviction
	@./01-add-tolerations.sh

.PHONY: deploy-dcm
deploy-dcm: ## Step 2: Deploy DCM pod by applying/updating DeviceConfig
	@./02-deploy-dcm.sh

.PHONY: taint
taint: ## Step 3: Taint node to evict workloads and prevent scheduling
	@./03-taint-node.sh

.PHONY: label
label: ## Step 4: Label node to indicate partitioning profile
	@./04-label-node.sh

.PHONY: verify
verify: ## Step 5: Verify DCM has partitioned the node
	@./05-verify-partition.sh

.PHONY: untaint
untaint: ## Step 6: Un-taint node to allow workload scheduling
	@./06-untaint-node.sh


##@ Cleanup & Revert

.PHONY: cleanup
cleanup: ## Full cleanup - reverse all steps (interactive)
	@./cleanup.sh


##@ Help

.PHONY: help
help: ## Display available targets
	@awk 'BEGIN {printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5); } /^[a-zA-Z0-9_-]+:.*?##/ { printf "  \033[36m%-30s\033[0m %s\n", $$1, substr($$0, index($$0, $$3)); }' $(MAKEFILE_LIST)
	@echo ""
	@echo "Configuration:"
	@echo "  NODE_NAME=$(NODE_NAME)"
	@echo "  PROFILE_NAME=$(PROFILE_NAME)"
	@echo "  NAMESPACE=$(NAMESPACE)"
	@echo ""
	@echo "Override variables:"
	@echo "  make all NODE_NAME=other-node PROFILE_NAME=spx-profile"
	@echo ""
