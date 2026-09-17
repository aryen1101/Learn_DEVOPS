# Kubernetes Fundamentals

## Docker Swarm

Docker Swarm is Docker's native clustering and orchestration tool. It groups multiple Docker hosts into a single cluster (a "swarm") so containers can be deployed and scaled across many machines using the same Docker CLI and Compose files.

**Architecture**

- **Manager Nodes** - maintain cluster state, schedule services and handle orchestration. They use the Raft consensus algorithm, so an odd number (3 or 5) is recommended.
- **Worker Nodes** - run the tasks (containers) assigned by managers.
- **Service** - the desired state of an application (image, replicas, ports, networks).
- **Task** - a single running container that is one unit of a service.
- **Overlay Network** - lets containers on different nodes talk to each other securely.
- **Routing Mesh** - any node can accept traffic on a published port and route it to the correct container, even on another node.

## Problems with Docker Swarm

- **Limited auto-scaling** - no built-in scaling based on CPU or memory; replicas must be scaled manually.
- **Basic health checks and self-healing** - only simple container restarts; no advanced readiness, liveness or startup probes.
- **Weak storage support** - limited options for persistent and dynamically provisioned storage.
- **Basic networking** - no native Ingress controller or advanced traffic routing policies.
- **Limited deployment strategies** - only rolling updates; no native blue-green or canary support.
- **Small ecosystem** - fewer tools, plugins and community support compared to Kubernetes.
- **Not cloud-native** - poor integration with cloud providers for load balancers, volumes and node management.
- **Slower development** - after Docker Inc. shifted focus, Swarm received far fewer updates.

## Why Kubernetes?

Kubernetes (K8s) is an open-source container orchestration platform originally built by Google and now maintained by the CNCF. It solves the limitations of Swarm and has become the industry standard.

- **Declarative desired state** - you describe what you want in YAML and Kubernetes keeps the cluster in that state.
- **Self-healing** - restarts, replaces and reschedules failed Pods automatically.
- **Auto-scaling** - Horizontal Pod Autoscaler, Vertical Pod Autoscaler and Cluster Autoscaler.
- **Advanced health checks** - liveness, readiness and startup probes.
- **Rich networking** - Services, Ingress, Network Policies and pluggable CNI.
- **Storage orchestration** - PersistentVolumes with dynamic provisioning from any cloud or on-prem storage.
- **Multiple deployment strategies** - rolling update, recreate, and blue-green / canary patterns.
- **Cloud-native and portable** - runs the same on any cloud, on-prem or locally; every major cloud offers a managed service (EKS, GKE, AKS).
- **Huge ecosystem** - Helm, Prometheus, Istio, ArgoCD and a very large community.

## Kubernetes Architecture

A cluster consists of a **Control Plane** (the brain that makes decisions) and **Worker Nodes** (where the application containers actually run).

### Control Plane Components

- **kube-apiserver** - the entry point of the cluster. Every request from kubectl, the dashboard or internal components goes through it. It validates the request and stores the result in etcd.
- **etcd** - a distributed, consistent key-value store that holds the entire cluster state. It is the single source of truth.
- **kube-scheduler** - watches for Pods without a node and picks the best node for them based on available resources, affinity rules, taints and tolerations.
- **kube-controller-manager** - runs all the controllers (Node, ReplicaSet, Deployment, Job, Endpoint, etc.). Each controller continuously compares the current state to the desired state and fixes any difference.
- **cloud-controller-manager** - connects the cluster to the cloud provider for load balancers, storage volumes and node lifecycle.

### Worker Node Components

- **kubelet** - the agent on every node. It takes Pod specs from the API server, starts the containers through the container runtime and reports their health back.
- **kube-proxy** - maintains network rules on the node so traffic to a Service reaches the right Pods. Provides basic load balancing.
- **Container Runtime** - the software that actually runs containers, such as containerd or CRI-O, through the Container Runtime Interface (CRI).

### Core Kubernetes Objects

- **Pod** - the smallest deployable unit; one or more containers that share network and storage.
- **ReplicaSet** - keeps a fixed number of identical Pods running at all times.
- **Deployment** - manages ReplicaSets and provides rolling updates and rollbacks.
- **Service** - a stable IP and DNS name that load balances traffic to a set of Pods (ClusterIP, NodePort, LoadBalancer).
- **Ingress** - manages external HTTP/HTTPS access to Services with routing rules.
- **Namespace** - a virtual cluster that isolates resources inside the same physical cluster.
- **ConfigMap & Secret** - keep configuration and sensitive data outside the container image.
- **Volume / PersistentVolume** - storage that survives container restarts.
- **DaemonSet** - runs one copy of a Pod on every node (for logging, monitoring agents).
- **StatefulSet** - manages stateful applications with stable identities and storage (databases).
- **Job / CronJob** - run tasks that finish, once or on a schedule.

### How it Works Together

1. A user applies a YAML manifest through kubectl to the API server.
2. The API server validates it and saves the desired state in etcd.
3. The controller manager notices the new object and creates the required Pods.
4. The scheduler assigns each Pod to a suitable node.
5. The kubelet on that node pulls the image and starts the containers via the container runtime.
6. kube-proxy updates network rules so the Pods are reachable through their Service.
