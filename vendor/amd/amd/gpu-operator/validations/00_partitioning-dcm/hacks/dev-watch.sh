#!/bin/bash


# in the node
cat /sys/module/amdgpu/drivers/pci\:amdgpu/*/{available_compute_partition,available_memory_partition}
cat /sys/module/amdgpu/drivers/pci\:amdgpu/0000\:05\:00.0/{available_compute_partition,current_compute_partition,available_memory_partition,current_memory_partition}
cat /etc/modprobe.d/amdgpu-blacklist.conf
cat /sys/module/amdgpu/version


# in the cluster
watch oc get pod,ds,deploy,rs -n openshift-amd-gpu
kubectl logs -n openshift-amd-gpu -l app.kubernetes.io/name=device-config-manager -f
kubectl exec -n $NAMESPACE $(kubectl get pods -n $NAMESPACE -l app.kubernetes.io/name=device-config-manager -o jsonpath='{.items[0].metadata.name}') -- amd-smi partition --memory
