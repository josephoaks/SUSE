#!/bin/sh

# Clean-up to re-install
file='/usr/local/bin/k3s-agent-uninstall.sh'
if [ -f $file ]; then
  /usr/local/bin/k3s-agent-uninstall.sh
  rm -rf /etc/rancher
  rm -rf /var/lib/rancher
fi

# Install fresh
TOKEN=`/usr/bin/cat node-token`
SERVER='https://pi.pirate.com:6443'
HOSTNAME=`/usr/bin/hostname -f`
K3S='v1.23.8+k3s1'

curl -sfL https://get.k3s.io | K3S_TOKEN="$TOKEN" K3S_URL="$SERVER:6443" K3S_NODE_NAME="$HOSTNAME" INSTALL_K3S_VERSION="$K3S" sh -
