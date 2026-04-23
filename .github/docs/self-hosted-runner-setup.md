# Self-Hosted Runner Setup on RHCOS

Steps to install and configure a GitHub Actions self-hosted runner on a Red Hat Enterprise Linux CoreOS (RHCOS) node.

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
curl -sL https://github.com/actions/runner/releases/download/v2.323.0/actions-runner-linux-x64-2.323.0.tar.gz | tar xz
./config.sh --url https://github.com/<owner>/<repo> --token <TOKEN> --name amd-lab-runner --labels self-hosted --unattended --replace
```

## 3. Fix SELinux context

RHCOS enforces SELinux, which blocks execution from the home directory by default.

```bash
sudo chcon -R -t bin_t ~/actions-runner
```

## 4. Install and start the systemd service

```bash
cd ~/actions-runner
sudo ./svc.sh install core
sudo ./svc.sh start
```

## 5. Configure cluster access

Copy the kubeconfig to the default path so both the runner service and SSH sessions can use it without extra env vars.

```bash
mkdir -p ~/.kube
sudo cp /etc/kubernetes/static-pod-resources/kube-apiserver-certs/secrets/node-kubeconfigs/lb-ext.kubeconfig ~/.kube/config
sudo chown core:core ~/.kube/config
chmod 600 ~/.kube/config
```

## 6. Verify

```bash
# On the node
sudo systemctl status actions.runner.<owner>-<repo>.<runner-name>.service

# From your workstation
gh api repos/<owner>/<repo>/actions/runners -q '.runners[] | "\(.name) | \(.status)"'
```

## Service management

```bash
sudo ./svc.sh start    # start
sudo ./svc.sh stop     # stop
sudo ./svc.sh status   # check status
sudo ./svc.sh uninstall # remove service
```
