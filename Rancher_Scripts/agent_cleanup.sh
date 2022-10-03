#!/bin/sh

# Clean-up script

/usr/local/bin/k3s-agent-uninstall.sh
rm -rf /var/lib/rancher
rm -rf /etc/rancher
