# Installing K3S

## Single node install

```text
curl -sfL https://get.k3s.io | K3S_NODE_NAME="<fqdn>" K3S_KUBECONFIG_MODE=0644 sh -
```

*If you want to setup K3S with etcd*

```text
curl -sfL https://get.k3s.io | K3S_NODE_NAME="<fqdn>" INSTALL_K3S_EXEC="server --cluster-init" K3S_KUBECONFIG_MODE=0644 sh -
```

*If you want to specify a version of K3S, add the following before the `sh -`*

```text
INSTALL_K3S_VERSION=<version>
```

Your command would now look like this 

```text
curl -sfL https://get.k3s.io | K3S_NODE_NAME="<fqdn>" INSTALL_K3S_EXEC="server --cluster-init" K3S_KUBECONFIG_MODE=0644 INSTALL_K3S_VERSION=<version> sh -
```

### Copy your K3S config to a local directory

```text
cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
```

Congrats your done, but wait, what if you want to setup a cluster? Using the node we just setup using the commands above,
we can set this as a primary server/master node (this has many terms), it's the main node! We are going to use this to add
our additional nodes to using the following commands... *Clusters should be in odd number sets, ideally minimum of 3*

## Setting up a K3S Cluster

We need the master nodes `node-token` to get this run the following command, we need this to setup the other nodes in the cluster.

```text
cat /var/lib/rancher/k3s/server/node-token
```

## Adding nodes to the cluster

```text
curl -sfL https://get.k3s.io | K3S_TOKEN="<node_token>" K3S_URL="https://<fqdn of the master node>:6443" K3S_NODE_NAME="<fqdn_node>" sh -
```

*repeat for each node that will join that cluster, modifying the <fqdn_node>*
