# Kubernetes Cheat Sheet

## kubectl common commands

### Namespaces

`kubectl get ns` # lists all namespaces in the cluster
`kubectl describe ns <namespace-name>` # provides detailed information about a specific namespace
*you can use 'ns' or fully written out 'namespace'*

### list resources

`kubectl get [pods, svc, deploy]` # lists the individual resources in the cluster
`kubectl get pods -o wide` same as above but gives more detailed output

### Starting/Deploying workloads

`kubectl create deployment <name> --image=<image_name>`
i.e. `kubectl create deployment nginx --image=nginx`
`kubectl apply -f nginx.yaml` # this applies a manifests and can start/deploy, setup the service, expose port etc...

### Scaling workloads

`kubectl scale deployment nginx --replicas=X` # increase/decrease X to scale up or down the number of deployments

### Logs & Debugging

`kubectl get pods`
`kubectl logs <pod_name>`
i.e. `kubectl logs nginx-6d698f9c4c-2vlgb`
add a `-f` to stream the logs to stdout

## ConfigMap kind's:

### Workloads (Run Applications)

| Kind        | Purpose                             | When to Use              |
|-------------|-------------------------------------|--------------------------|
| Pod         | Smallest runnable unit              | Debugging, one-off tests |
| Deployment  | Stateless apps with rolling updates | Web apps, APIs           |
| ReplicaSet  | Ensures Pod count                   | Managed by Deployment    |
| StatefulSet | Stable identity + storage           | Databases, Kafka         |
| DaemonSet   | One Pod per node                    | Logging, monitoring      |
| Job         | Run once until success              | Migrations, batch jobs   |
| CronJob     | Scheduled Jobs                      | Backups, cleanup         |

### Networking (Expose Apps)

| Kind            | Purpose                 | Notes            |
|-----------------|-------------------------|------------------|
| Service         | Stable IP + DNS         | Fronts Pods      |
| └─ ClusterIP    | Internal only (default) | Most common      |
| └─ NodePort     | NodeIP:Port             | Rarely used      |
| └─ LoadBalancer | Cloud external LB       | Cloud only       |
| Ingress         | HTTP/HTTPS routing      | Needs controller |

### Configuration

| Kind      | Purpose                  |
|-----------|--------------------------|
| ConfigMap | Non-secret config        |
| Secret    | Passwords, tokens, certs |

### Storage

| Kind                        | Purpose              |
|-----------------------------|----------------------|
| PersistentVolume (PV)       | Actual storage       |
| PersistentVolumeClaim (PVC) | Request storage      |
| StorageClass                | Dynamic provisioning |

### Security & Access (RBAC)

| Kind               | Purpose            |
|--------------------|--------------------|
| ServiceAccount     | Pod identity       |
| Role / ClusterRole | Permissions        |
| RoleBinding        | Attach permissions |

### Cluster & Organization

| Kind      | Purpose           |
|-----------|-------------------|
| Namespace | Logical isolation |
| Node      | Worker machine    |
