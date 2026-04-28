# Argo Workflows Controller

Static manifests for the Argo Workflows controller, required by the AMD GPU Operator auto-remediation feature.

## How these manifests were generated

```bash
helm repo add argo https://argoproj.github.io/argo-helm --force-update

helm template argo-workflows argo/argo-workflows \
  --version 1.0.6 \
  --namespace argo-workflows \
  --set crds.install=false \
  --set server.enabled=false \
  > 01_argo-workflows-controller.yaml
```

- `--version 1.0.6` is the **chart** version (app version `v4.0.3`). Use `helm search repo argo/argo-workflows --versions` to find the mapping.
- `crds.install=false` because OpenShift AI already provides the Argo CRDs.
- `server.enabled=false` because the GPU Operator only needs the controller, not the Argo UI.

The configmap must include `instanceID: amd-gpu-operator-remediation-workflow` so the controller picks up workflows created by the GPU Operator.

## To update the version

1. Find the new chart version: `helm search repo argo/argo-workflows --versions`
2. Re-run the `helm template` command above with the new `--version`
3. Replace `01_argo-workflows-controller.yaml` with the output
4. Update the version comments in `kustomization.yaml`
