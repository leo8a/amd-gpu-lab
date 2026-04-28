#!/bin/bash

# Show Compute Partitions
echo "=== Compute Partitions ==="
oc run test --rm -it --restart=Never --image=docker.io/rocm/rocm-terminal:latest --overrides='{"spec":{"hostIPC":true,"securityContext":{"supplementalGroups":[44,109]},"containers":[{"name":"test","image":"docker.io/rocm/rocm-terminal:latest","command":["rocm-smi"],"securityContext":{"privileged":true,"seccompProfile":{"type":"Unconfined"}},"volumeMounts":[{"name":"dev-kfd","mountPath":"/dev/kfd"},{"name":"dev-dri","mountPath":"/dev/dri"}]}],"volumes":[{"name":"dev-kfd","hostPath":{"path":"/dev/kfd"}},{"name":"dev-dri","hostPath":{"path":"/dev/dri"}}]}}'

# Show Memory Partitions
echo "=== Memory Partitions ==="
oc run test --rm -it --restart=Never --image=docker.io/rocm/rocm-terminal:latest --overrides='{"spec":{"hostIPC":true,"securityContext":{"supplementalGroups":[44,109]},"containers":[{"name":"test","image":"docker.io/rocm/rocm-terminal:latest","command":["rocm-smi","--showmemorypartition"],"securityContext":{"privileged":true,"seccompProfile":{"type":"Unconfined"}},"volumeMounts":[{"name":"dev-kfd","mountPath":"/dev/kfd"},{"name":"dev-dri","mountPath":"/dev/dri"}]}],"volumes":[{"name":"dev-kfd","hostPath":{"path":"/dev/kfd"}},{"name":"dev-dri","hostPath":{"path":"/dev/dri"}}]}}'

# Show Topology
echo "=== GPU Topology ==="
oc run test --rm -it --restart=Never --image=docker.io/rocm/rocm-terminal:latest --overrides='{"spec":{"hostIPC":true,"securityContext":{"supplementalGroups":[44,109]},"containers":[{"name":"test","image":"docker.io/rocm/rocm-terminal:latest","command":["rocm-smi","--showtopo"],"securityContext":{"privileged":true,"seccompProfile":{"type":"Unconfined"}},"volumeMounts":[{"name":"dev-kfd","mountPath":"/dev/kfd"},{"name":"dev-dri","mountPath":"/dev/dri"}]}],"volumes":[{"name":"dev-kfd","hostPath":{"path":"/dev/kfd"}},{"name":"dev-dri","hostPath":{"path":"/dev/dri"}}]}}'
