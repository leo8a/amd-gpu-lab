# Self-Hosted Runner Setup

Steps to install and configure a GitHub Actions self-hosted runner on a Red Hat Enterprise Linux (RHEL) or CoreOS (RHCOS) node.

## Prerequisites

- SSH access to the RHCOS node
- `sudo` privileges (user `core`)
- A GitHub repo with Actions enabled

## 1. Get a registration token

```bash
gh api -X POST repos/<owner>/<repo>/actions/runners/registration-token -q '.token'
```

## 2. Install and register the runner

```bash
mkdir -p ~/actions-runner && cd ~/actions-runner
curl -sL https://github.com/actions/runner/releases/download/v2.334.0/actions-runner-linux-x64-2.323.0.tar.gz | tar xz
./config.sh --url https://github.com/<owner>/<repo> --token <TOKEN> --name amd-lab-runner --labels self-hosted --unattended --replace
```

## 3. Fix SELinux context

RHCOS enforces SELinux, which blocks execution from the home directory by default.

```bash
sudo chcon -R -t bin_t ~/actions-runner
```

## 4. Enable lingering for rootless podman

The runner service uses rootless `podman` (via the `ci-tools` container) for the
validation stages. Rootless podman needs `/run/user/<uid>` to set up its OCI
runtime (`crun`), and `systemd-logind` only creates that directory while the user
has an active login session — **unless lingering is enabled**. Because the runner
runs as a headless systemd service (no login session), you MUST enable lingering
or every container-based stage fails with
`Error: default OCI runtime "crun" not found: invalid argument` (exit code 125).

```bash
sudo loginctl enable-linger core
loginctl show-user core | grep Linger   # expect: Linger=yes
```

This only creates `/var/lib/systemd/linger/core` — it is not Ignition/MCO-managed,
so it does not trigger machine-config drift on RHCOS.

## 5. Install and start the systemd service

```bash
cd ~/actions-runner
sudo ./svc.sh install core
sudo ./svc.sh start
```

## 6. Configure cluster access

Copy the kubeconfig to the default path so both the runner service and SSH sessions can use it without extra env vars.

```bash
mkdir -p ~/.kube
sudo cp /etc/kubernetes/static-pod-resources/kube-apiserver-certs/secrets/node-kubeconfigs/lb-ext.kubeconfig ~/.kube/config
sudo chown core:core ~/.kube/config
chmod 600 ~/.kube/config
```

## 7. Verify

```bash
# On the node
sudo systemctl status actions.runner.<owner>-<repo>.<runner-name>.service

# From your workstation
gh api repos/<owner>/<repo>/actions/runners -q '.runners[] | "\(.name) | \(.status)"'
```

## Known warnings

### "Free space left: 0 MB" — false positive on RHCOS

On RHCOS, GitHub Actions checks free space on `/`, which is a read-only composefs mount that is always 100% full by design. The actual writable partition is `/sysroot` (mounted on `/var`), which typically has terabytes of free space. This warning does NOT indicate a real disk space problem and can be safely ignored. This does not apply to standard RHEL installations.

```bash
$ df -h / /var
Filesystem      Size  Used Avail Use% Mounted on
composefs       5.9M  5.9M     0 100% /          <-- always full, read-only image (RHCOS only)
/dev/nvme1n1p4   28T  305G   28T   2% /var        <-- actual writable storage
```

### `default OCI runtime "crun" not found` — lingering is disabled

Container-based stages fail with exit code 125 and
`Error: default OCI runtime "crun" not found: invalid argument`, while `oc`-only
stages (Preflight, Install) pass. This means rootless podman has no
`/run/user/<uid>` runtime directory because lingering is off — see step 4. Note
the failure is invisible when debugging over SSH, since an interactive login
recreates `/run/user/<uid>` and makes podman "work when run manually." Confirm and
fix:

```bash
loginctl show-user core | grep Linger   # Linger=no is the problem
sudo loginctl enable-linger core
```

## Service management

```bash
sudo ./svc.sh start    # start
sudo ./svc.sh stop     # stop
sudo ./svc.sh status   # check status
sudo ./svc.sh uninstall # remove service
```
