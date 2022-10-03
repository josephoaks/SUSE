#!/bin/sh

# Clean-up to re-install
file='/usr/local/bin/k3s-uninstall.sh'
if [ -f $file ]; then
  /usr/local/bin/k3s-uninstall.sh
  rm -rf /var/lib/rancher
  rm -rf /etc/rancher
  rm -rf /root/.kube/config
fi

# Variable initialization
SERVER='pi.pirate.com'
K3S='v1.23.8+k3s1'

# Install fresh
dir='/root/.kube'
if [ ! -d $dir ]; then
  mkdir $dir
  chmod 0600 $dir
fi

curl -sfL https://get.k3s.io | K3S_NODE_NAME=$SERVER INSTALL_K3S_EXEC="server --cluster-init" K3S_KUBECONFIG_MODE=0644 INSTALL_K3S_VERSION=$K3S sh -

cp -rip /etc/rancher/k3s/k3s.yaml $dir/config

TOKEN=`/usr/bin/cat /var/lib/rancher/k3s/server/node-token`

scp /var/lib/rancher/k3s/server/node-token pi1:/root/node-token
scp /var/lib/rancher/k3s/server/node-token pi2:/root/node-token

ssh pi1 '/bin/sh /root/agent_setup.sh'
ssh pi2 '/bin/sh /root/agent_setup.sh'
