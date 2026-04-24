# Cluster-Wide RDMA Validation

Automated cluster validation framework that validates RDMA connectivity, GPU performance, and network infrastructure across multiple nodes.

Based on the [AMD Network Operator Cluster Validation Framework](https://instinct.docs.amd.com/projects/network-operator/en/latest/cluster_validation_framework/README.html).

## What It Does

1. Deploys Kubeflow MPI Operator for distributed job execution
2. Creates ConfigMaps with validation scripts and MPIJob templates
3. Deploys a CronJob that runs periodic cluster validation checks
4. Validates RDMA devices, network connectivity, and performance benchmarks
5. Applies node labels based on validation results

## Deploy

```bash
oc apply --server-side -k .
```

> **Note**: The `--server-side` flag is required for the MPIJob CRD due to large annotation size.

## Verify Deployment

```bash
# 1. Check CronJob
oc get cronjob cluster-validation-cron-job

# 2. Check MPI Operator
oc get all -n mpi-operator
oc get crds | grep mpijobs

# 3. List triggered jobs
oc get jobs
```

## Manual Trigger

To manually trigger validation without waiting for the CronJob schedule:

```bash
# Create a one-time job from the CronJob
oc create job --from=cronjob/cluster-validation-cron-job cluster-validation-manual

# Follow the logs
oc logs -f job/cluster-validation-manual -c submit-mpijob

# Check job status
oc get job cluster-validation-manual
```

> **Note**: If testing multiple times, remove the timestamp annotation to bypass the validation interval:
>
> ```bash
> oc annotate node <node-name> amd.com/cluster-validation-last-run-timestamp-
> ```

## Check Validation Results

```bash
# 1. Check node labels
oc get nodes --show-labels | grep cluster-validation-status
oc describe node | grep "amd.com/cluster-validation\|Name:"

# 2. View CronJob logs
oc logs job/cluster-validation-cron-job-<timestamp>

# 3. View MPIJob launcher logs
oc logs job/cluster-validation-mpi-job-<timestamp>-launcher
```

## Node Label Examples

| Node   | Label                                      | Meaning                       |
|--------|--------------------------------------------|-------------------------------|
| node-a | `amd.com/cluster-validation-status=passed` | Node passed all RCCL tests    |
| node-b | `amd.com/cluster-validation-status=failed` | Node failed one or more tests |
| node-c | (no label)                                 | Node not in candidate set     |

## Expected Behavior

The CronJob runs on schedule (default: hourly) and:

- Validates RDMA device presence and configuration
- Runs distributed RCCL performance tests via MPIJobs
- Compares results against performance thresholds
- Applies node labels based on validation results

## Cleanup

To remove all cluster validation resources:

```bash
# Delete all resources via kustomization
oc delete -k .

# Remove node labels (optional)
oc label nodes --all amd.com/cluster-validation-status-
oc label nodes --all amd.com/cluster-validation-candidate-
oc label nodes --all amd.com/gpu-validation-test-
```

## Prerequisites

- AMD Network Operator deployed
- **At least 2 nodes** labeled with `feature.node.kubernetes.io/amd-nic=true`
- Kubeflow MPI Operator v0.8.0 (automatically deployed by kustomization)

## Files

- MPI Operator (remote) - Kubeflow MPI Operator for distributed MPI job execution
- `cluster-validation-config.yaml` - ConfigMaps with node selection, MPIJob templates, and performance thresholds
- `cluster-validation-job.yaml` - CronJob definition, MPIJob template, and RBAC resources

## Configuration Notes

Before deployment, operators may need to customize:

- **Image tags**: Update `roce-workload` and `network-operator-utils` image versions in `cluster-validation-job.yaml`
- **Resource limits**: Ensure `slotsPerWorker` and resource limits match GPU/NIC configuration
- **CronJob schedule**: Modify `spec.schedule` to adjust validation frequency (default: hourly)
- **Debug mode**: Set `DEBUG_DELAY` environment variable to pause after job completion for troubleshooting

## References

- [MPI Operator Introduction](https://medium.com/kubeflow/introduction-to-kubeflow-mpi-operator-and-industry-adoption-296d5f2e6edc)
- [MPI Operator Documentation](https://www.kubeflow.org/docs/components/trainer/legacy-v1/user-guides/mpi/)
- [MPI Operator GitHub](https://github.com/kubeflow/mpi-operator/blob/master/README.md)
