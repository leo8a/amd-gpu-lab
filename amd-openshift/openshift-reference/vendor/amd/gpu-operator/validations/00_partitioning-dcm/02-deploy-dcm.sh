#!/bin/bash
#
# Step 2: Deploy the DCM Pod by Applying/Updating the DeviceConfig
#
# Creates a ConfigMap with GPU partition profiles and patches the DeviceConfig CR
# to enable and configure the Device Config Manager, which orchestrates GPU partitioning.
#
# GPU Partition Info (reference from node):
# - Available compute partitions: SPX, DPX, QPX, CPX
# - Available memory partitions: NPS1, NPS2, NPS4
#
# Commands to check on GPU node:
#   ls /sys/module/amdgpu/drivers/pci:amdgpu/
#   cat /sys/module/amdgpu/drivers/pci:amdgpu/0000:05:00.0/available_compute_partition
#   cat /sys/module/amdgpu/drivers/pci:amdgpu/0000:05:00.0/available_memory_partition
#

set -euo pipefail

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         Step 2: Deploy Device Config Manager                   ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Creating DCM profile ConfigMap...
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: config-manager-config
  namespace: $NAMESPACE
data:
  config.json: |
    {
      "gpu-config-profiles": {
        "spx-profile-nps1": {
          "skippedGPUs": {
            "ids": []
          },
          "profiles": [
            {
              "computePartition": "SPX",
              "memoryPartition": "NPS1",
              "numGPUsAssigned": 8
            }
          ]
        },
        "dpx-profile-nps2": {
          "skippedGPUs": {
            "ids": []
          },
          "profiles": [
            {
              "computePartition": "DPX",
              "memoryPartition": "NPS2",
              "numGPUsAssigned": 8
            }
          ]
        },
        "cpx-profile-nps4": {
          "skippedGPUs": {
            "ids": []
          },
          "profiles": [
            {
              "computePartition": "CPX",
              "memoryPartition": "NPS4",
              "numGPUsAssigned": 8
            }
          ]
        }
      },
      "gpuClientSystemdServices": {
        "names": ["amd-metrics-exporter", "gpuagent"]
      }
    }
EOF


# Enabling Device Config Manager...
kubectl patch deviceconfig amdgpu-driver-install -n $NAMESPACE --type='merge' -p '{
  "spec": {
    "configManager": {
      "enable": true,
      "image": "docker.io/rocm/device-config-manager:v1.4.1",
      "imagePullPolicy": "IfNotPresent",
      "config": {
        "name": "config-manager-config"
      }
    }
  }
}'


# Wait for config-manager pod to be ready
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=device-config-manager \
  -n $NAMESPACE \
  --timeout=300s


echo ""


# [root@smc6217gpu ~]# cat /sys/module/amdgpu/drivers/pci\:amdgpu/0000\:05\:00.0/{available_compute_partition,current_compute_partition,available_memory_partition,current_memory_partition}
# SPX, DPX, QPX, CPX
# SPX, DPX, QPX, CPX
# NPS1



# [root@smc6217gpu ~]# cat /sys/module/amdgpu/version
# 6.16.6

# [root@smc6217gpu ~]# cat /etc/modprobe.d/amdgpu-blacklist.conf
# blacklist amdgpu
