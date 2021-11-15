# Installing Rancher 2.6.x on SUSE 15.3

## Pre-setup work prior to installing Rancher

1. Setup DNS, probably the most important thing to be able to use Rancher
1. Install extra packages to make life a little bit easier
1. If this is internal you can choose to disable firewalld or you have to open ports
1. Setup user
1. Setup region and time server
1. New with Kubernetes 1.20.x install apparmor if it is not already installed

*See [suse_setup.md](suse_setup.md)

## Install Helm

wget -O helm.tar.gz https://get.helm.sh/helm-v3.6.3-linux-amd64.tar.gz
tar xfz helm-v3.6.3-linux-amd64.tar.gz
cp linux-amd64/helm /usr/local/bin

## Install Kubernetes (K3S)

Use this command to grab the current version of K3S, to specify a version, add `INSTALL_K3S_VERSION=<version>` prior to the `sh -`

```text
curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE=0644 sh -
```

Copy your K3S config to your local directory
```text
cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
```

## Using Helm to install jetstack/cert-manager and Rancher

### Add the repos to Helm

```text
helm repo add jetstack https://charts.jetstack.io
helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
```

*Check for latest versions and adjust as needed*
```text
helm fetch jetstack/cert-manager --version v1.6.1
helm fetch rancher-latest/rancher --version=v2.6.2
```

```text
helm repo update
```

### Install cert-manager

```text
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true
```

### Install Rancher

```text
helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --create-namespace \
  --set hostname=<fqdn> \
  --set bootstrapPassword=<password>
```
