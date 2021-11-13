# Installing Rancher 2.6.x on SUSE 15.3

## Pre-setup work to be done prior to installing Rancher

1. Setup DNS, probably the most important thing to be able to use Rancher
1. Install extra packages to make life a little bit easier
1. If this is internal you can choose to disable firewalld or you have to open ports
1. Setup user
1. Setup region and time server
1. New with Kubernetes 1.20.x install apparmor if it is not already installed


wget -O helm.tar.gz https://get.helm.sh/helm-v3.6.3-linux-amd64.tar.gz
tar xfz helm-v3.6.3-linux-amd64.tar.gz

curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION=v1.19.15+k3s2 K3S_KUBECONFIG_MODE=0644 sh -
curl -sfL https://get.k3s.io | K3S_KUBECONFIG_MODE=0644 sh -
cp /etc/rancher/k3s/k3s.yaml ~/.kube/config

helm repo add jetstack https://charts.jetstack.io
helm fetch jetstack/cert-manager --version v1.6.1

helm repo add rancher-latest https://releases.rancher.com/server-charts/latest
helm fetch rancher-latest/rancher --version=v2.6.2
helm repo update

kubectl create namespace cert-manager
helm template cert-manager ./cert-manager-v1.6.1.tgz --output-dir . --namespace cert-manager

helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --set installCRDs=true

kubectl create namespace cattle-system
helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --set hostname=rancher.pirate.com \
  --set bootstrapPassword=rancher

helm install rancher rancher-latest/rancher \
  --namespace cattle-system \
  --create-namespace \
  --set hostname=rancher.pirate.com \
  --set replicas=1
  --set bootstrapPassword=rancher
