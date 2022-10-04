#!/bin/sh

###############################
# Control-plane Setup Section #
###############################

# Clean-up to re-install
if [ -f '/usr/local/bin/k3s-uninstall.sh' ]; then
  /usr/local/bin/k3s-uninstall.sh
  rm -rf /var/lib/rancher
  rm -rf /etc/rancher
  rm -rf /root/.kube/config
fi

# Variable initialization
SERVER=`hostname -f`
read -ep "Enter K3S version you wish to install (v1.23.8+k3s1): " K3S

# Install fresh
dir='/root/.kube'
if [ ! -d $dir ]; then
  mkdir $dir
  chmod 0600 $dir
fi

curl -sfL https://get.k3s.io | K3S_NODE_NAME=$SERVER INSTALL_K3S_EXEC="server --cluster-init" K3S_KUBECONFIG_MODE=0644 INSTALL_K3S_VERSION=$K3S sh -

cp -rip /etc/rancher/k3s/k3s.yaml $dir/config

TOKEN=`/usr/bin/cat /var/lib/rancher/k3s/server/node-token`

#######################
# Agent Setup Section #
#######################
echo ""
echo "#"
echo "# Agent Setup Section"
echo "#"
echo ""
echo "Enter the agent nodes names, etc fqdn1 fqdn2 fqdn3"
read -a details
len=${#details[@]}

for (( i=0; i<$len; i++)); do
HOSTNAME=${details[$i]}
###########################
# Make Agent Setup Script #
###########################
cat <<EOF > .agent_setup${details[$i]}.sh
#!/bin/sh

# Clean-up to re-install
if [ -f "/usr/local/bin/k3s-agent-uninstall.sh" ]; then
  /usr/local/bin/k3s-agent-uninstall.sh
  rm -rf /etc/rancher
  rm -rf /var/lib/rancher
fi

# Install fresh
curl -sfL https://get.k3s.io | K3S_TOKEN=$TOKEN K3S_NODE_NAME=$HOSTNAME INSTALL_K3S_VERSION=$K3S sh -s agent --server https://$SERVER:6443
EOF
#############################
# End of Agent Setup Script #
#############################

  scp .agent_setup${details[$i]}.sh root@${details[$i]}:/root/agent_setup.sh
  ssh root@${details[$i]} '/bin/sh /root/agent_setup.sh'
  rm -f .agent_setup${details[$i]}.sh
done
