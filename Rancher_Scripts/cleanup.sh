#!/bin/sh

# Clean-up to re-install
/usr/local/bin/k3s-uninstall.sh
rm -rf /var/lib/rancher
rm -rf /etc/rancher
rm -rf /root/.kube/config

ssh pi1 '/bin/sh /root/agent_cleanup.sh'
ssh pi2 '/bin/sh /root/agent_cleanup.sh'
