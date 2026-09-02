# Kubernetes Notes


## 1. Orchestration: Why We Need It

Docker can create and run containers. But imagine 100 containers running across 10 servers.
You need something to automatically:

- Start containers
- Restart crashed containers
- Scale containers up and down
- Distribute containers across servers
- Connect containers through networking
- Manage storage
- Perform rolling updates
- Load-balance traffic

That is what a **container orchestrator** does.

### The Tooling Ladder

| Tool | What it does | Scope |
|------|--------------|-------|
| **Docker** | Build and run individual containers | One container at a time |
| **Docker Compose** | Define and run a multi-container app from one YAML file | Single machine (one host) |
| **Docker Swarm** | Orchestrate containers across multiple machines as one cluster | Small / simple multi-host clusters |
| **Kubernetes** | Full orchestration platform — scaling, self-healing, networking, storage, rolling updates | Large production clusters |

> **Note:** The real difference is not a container *count*. Compose is limited to one host; Swarm and Kubernetes span many hosts. You move to Kubernetes when you need production-grade features (autoscaling, advanced networking, a huge ecosystem), not just because you crossed 20 containers.

---

## 2. Docker Swarm

Docker Swarm is Docker's own built-in container orchestration system. It lets multiple Docker machines work together as one cluster and manages containers/services across them.

### Why use Swarm?

Suppose you have a backend. Instead of running only one container, you run 3 replicas:

```
Backend Service
 |-- Container 1
 |-- Container 2
 +-- Container 3
```

Swarm keeps these replicas running. If one container fails, Swarm creates another to maintain the desired number.

### Manager vs Worker

**Manager:**
- Controls the Swarm cluster
- Creates and manages services
- Decides where containers should run
- (A manager can also run workloads unless you drain it)

**Worker:**
- Runs the containers/tasks assigned by the manager

Kubernetes uses the same basic idea with different names: **Control Plane** and **Worker Nodes**.

---

## 3. What is Kubernetes?

**Kubernetes (K8s)** is a platform that automatically deploys, manages, scales, and maintains containerized applications across one or more machines.

The key idea is the **declarative model**: you describe *what* you want (the **desired state**), and Kubernetes continuously works to make reality match it (the **actual state**). You don't give step-by-step instructions.

When you create something in Kubernetes, you are creating a **Kubernetes API object** (also called a resource) — a Pod, Deployment, Service, ConfigMap, and so on.

---

## 4. Cluster Architecture

A **cluster** is a group of machines (nodes) working together as one system.

```
Kubernetes Cluster = Control Plane + Worker Nodes
```

Kubernetes follows a **Control Plane – Worker** architecture:

- **Control Plane** (historically called the "master") -> manages the cluster
- **Worker Nodes** -> actually run your applications

```
                     KUBERNETES CLUSTER
                             |
        +--------------------+--------------------+
        |                                         |
   CONTROL PLANE                            WORKER NODES
   (the brain)                              (the muscle)
        |                                         |
 +------+------+--------------+        +----------+----------+
 |      |      |              |        |          |          |
API  Scheduler  etcd     Controller  Node 1     Node 2     Node 3
Server                    Manager      |          |          |
                                    kubelet    kubelet    kubelet
                                   kube-proxy kube-proxy kube-proxy
                                    runtime    runtime    runtime
                                       |          |          |
                                     Pods       Pods       Pods
                                       |          |          |
                                  Containers Containers Containers
```

```
Kubernetes Cluster
|
|-- Control Plane -> manages the cluster
|
|-- Worker Node -> runs applications
|-- Worker Node -> runs applications
+-- Worker Node -> runs applications
```

**About the Control Plane and workloads:** the control plane's job is to manage the cluster, not to serve your app. In a real multi-node cluster, control plane nodes carry a **taint** (`node-role.kubernetes.io/control-plane:NoSchedule`) so your application Pods are not scheduled there. It is not that they *cannot* run Pods — the control plane components themselves usually run as Pods (static Pods) on that node. In a single-node setup like Minikube, that taint is removed so your apps can run on the only node available.

---

## 5. Control Plane Components

### 5.1 etcd — the cluster database

**etcd** is a distributed key-value store. It is the single source of truth for the whole cluster: all cluster state and configuration lives here.

It stores things like:
- What nodes exist
- What Pods exist
- What Deployments exist
- What the desired state is
- All configuration (ConfigMaps, Secrets, etc.)

> **Important:** Only the API Server talks to etcd. No other component reads or writes it directly. Losing etcd means losing the cluster, so etcd is what you back up.

**Remember:** etcd = the cluster's memory

### 5.2 kube-apiserver — the entry point

The **API Server** is how everything communicates with Kubernetes. `kubectl`, the dashboard, CI/CD pipelines, and even the other control plane components all go through it.

It:
- Receives requests (REST over HTTPS)
- Authenticates and authorizes them
- Validates them
- Persists the result to etcd
- Acts as the central communication hub

**Remember:** API Server = gatekeeper / entry point

### 5.3 kube-scheduler — placement

The **Scheduler** answers one question: *which Worker Node should run this Pod?*

It watches for newly created Pods that have no node assigned yet, then picks a node based on:
- Available CPU / memory (resource requests)
- Node selectors, affinity / anti-affinity rules
- Taints and tolerations
- Other scheduling constraints

> The Scheduler only *decides* and records the choice. The **kubelet** on the chosen node is what actually starts the Pod.

**Remember:** Scheduler = chooses the Worker Node

### 5.4 kube-controller-manager — the reconciler

The **Controller Manager** runs Kubernetes' control loops. It continuously compares the **actual state** of the cluster against the **desired state** and takes action when they differ.

It bundles many controllers into one process, for example:
- **Deployment / ReplicaSet controller** — keeps the right number of Pod replicas
- **Node controller** — notices when a node goes down
- **Job controller** — runs one-off tasks to completion
- **EndpointSlice controller** — keeps Service -> Pod mappings up to date

**Remember:** Controller Manager = "make reality match the spec"

### 5.5 cloud-controller-manager (cloud clusters only)

On a managed or cloud-hosted cluster (EKS, GKE, AKS), this component talks to the cloud provider's API to create load balancers, attach storage volumes, and manage node lifecycle. It does not exist on a plain local cluster like Minikube.

---

## 6. Worker Node Components

Every worker node runs **three** things:

### 6.1 kubelet — the node agent

The **kubelet** is the agent that runs on every node (including control plane nodes).

Its main job: **make sure the Pods assigned to this node are actually running and healthy.**

It also:
- Talks to the container runtime (through CRI) to start and stop containers
- Runs liveness / readiness / startup probes
- Reports node and Pod status back to the API Server through a regular heartbeat, so the control plane knows the node is alive

> The kubelet manages only Pods that came from the API Server (or from static Pod manifests). Containers you start by hand with `docker run` are invisible to it.

### 6.2 kube-proxy — Service networking

**kube-proxy** implements **Kubernetes Service** networking on each node. When traffic is sent to a Service's virtual IP (ClusterIP), kube-proxy forwards it to one of the healthy backing Pods, which gives you basic load balancing.

It does this by programming the node's `iptables` rules (or IPVS). Some modern clusters replace kube-proxy entirely with an eBPF-based CNI such as Cilium.

> **Correction to a common mix-up:** kube-proxy does **not** enforce NetworkPolicies, and it does not assign Pod IPs. Pod-to-Pod networking and NetworkPolicy enforcement are the job of the **CNI plugin** (Calico, Cilium, Flannel, Weave). kube-proxy is only about Service -> Pod traffic.

**Remember:** kube-proxy = routes Service traffic to Pods

### 6.3 Container runtime

The software that actually pulls images and runs containers — see the next section.

---

## 7. Container Runtime & CRI

**CRI (Container Runtime Interface)** is the standard interface/API that lets Kubernetes — specifically the kubelet — talk to a container runtime.

Kubernetes needs to run containers, but it does not implement low-level container execution itself. So it defines CRI, and any runtime that speaks CRI can be plugged in.

```
kubelet --CRI--> container runtime --> containers
```

Common CRI runtimes:
- **containerd** (the most common default)
- **CRI-O**

> **Note on Docker:** Docker Engine is not a CRI runtime. Kubernetes used to support it through a shim called *dockershim*, which was **removed in Kubernetes v1.24**. Docker-*built* images still work perfectly — they are standard OCI images. And under the hood, Docker itself uses containerd anyway.

---

## 8. Core Objects: Pods and Nodes

### 8.1 Pod

A **Pod** is the smallest deployable unit in Kubernetes. You do not deploy containers directly — you deploy Pods.

A Pod is a wrapper around **one or more containers that need to run together**. Containers in the same Pod share:

- **Network namespace** — one IP address per Pod; containers reach each other over `localhost`
- **Ports** (so two containers in one Pod cannot listen on the same port)
- **Storage volumes**
- The same lifecycle — they are scheduled, started, and killed together on the same node

```
Kubernetes Cluster
       |
   Worker Node
       |
      Pod  (one shared IP)
       |
   +---+---+
   |       |
Container Container
  Nginx    Sidecar
```

**In practice**, a Pod usually holds 1 main container, sometimes with a helper container. There are two different kinds of helper:

| Type | When it runs | Purpose |
|------|--------------|---------|
| **init container** | **Before** the main container, and must exit successfully first | Setup work: wait for a DB, run migrations, fetch config |
| **sidecar container** | **Alongside** the main container, for its whole life | Logging agent, metrics exporter, service-mesh proxy |

> These two get confused a lot. An init container finishes and exits; a sidecar keeps running.

Also note: you rarely create bare Pods yourself. You create a **Deployment**, which creates a **ReplicaSet**, which creates the Pods — that is what gives you self-healing and rolling updates.

```
Deployment -> ReplicaSet -> Pods -> Containers
```

### 8.2 Node

A **Node** is a machine (physical or virtual) that runs Kubernetes workloads. Worker nodes are where your applications actually run.

A node provides resources such as:
- CPU
- RAM
- Storage
- Network

Kubernetes uses these resources to schedule and run Pods.

---

## 9. Desired State vs Actual State

This is the core loop of Kubernetes. Example with a Deployment:

```yaml
replicas: 3
```

You are telling Kubernetes: *"I want 3 Pods running."*

**Desired State = 3 Pods**

Initially everything matches:

```
Pod 1  OK
Pod 2  OK
Pod 3  OK

Desired = 3
Actual  = 3      -> nothing to do
```

**Now Pod 2 crashes:**

```
Pod 1  OK
Pod 2  FAILED
Pod 3  OK

Desired = 3
Actual  = 2      -> mismatch
```

The ReplicaSet controller (inside the Controller Manager) detects the difference:

```
Controller Manager
       |
       | "Desired 3, actual 2"
       v
Creates a replacement Pod
       |
       v
Scheduler assigns it to a node
       |
       v
kubelet on that node starts it
```

Result:

```
Pod 1  OK
Pod 3  OK
Pod 4  OK    <- new Pod: new name, new IP

Desired = 3
Actual  = 3      -> reconciled
```

> Notice the replacement is a **new** Pod (Pod 4), not a revived Pod 2. Pods are disposable — never rely on a Pod's name or IP. That is exactly why **Services** exist: a Service gives you a stable name and IP in front of a changing set of Pods.

### Request Flow: What Happens on `kubectl apply`

```
1. kubectl apply -f deployment.yaml
        |
2. API Server  -> authenticate, authorize, validate
        |
3. etcd        -> desired state saved
        |
4. Controller Manager -> "this Deployment needs 3 Pods" -> creates Pod objects
        |
5. Scheduler   -> assigns each Pod to a Node
        |
6. kubelet on that Node -> asks the runtime (via CRI) to start containers
        |
7. kubelet reports status -> API Server -> etcd
```

---

## 10. Minikube

### 10.1 What is Minikube?

**Minikube** is a tool that runs a local Kubernetes cluster on your own machine — laptop, PC, or VM. It is built for **learning, development, and testing**, not for production.

It creates the whole cluster (control plane + node) inside a **single VM or container**, so one machine behaves like a full Kubernetes cluster.

```
Your Laptop
    |
    +-- Minikube (a VM or a Docker container)
            |
            +-- Single-node Kubernetes cluster
                    |-- Control Plane (api-server, etcd, scheduler, controller-manager)
                    +-- Node components (kubelet, kube-proxy, containerd)
                            |
                           Pods
```

By default it is **one node** acting as both control plane and worker — which is why the control plane taint is removed there and your Pods can actually run.

### 10.2 Why Minikube?

- No cloud account, no cost
- Starts and resets in minutes (`minikube delete`, then start fresh)
- Real Kubernetes — the same `kubectl` commands and YAML you would use in production
- Built-in addons: Ingress, dashboard, metrics-server, and more
- Supports multiple Kubernetes versions, so you can test upgrades

### 10.3 Prerequisites

- 2 CPUs or more, 2 GB free RAM, 20 GB free disk
- A **driver** — the container or VM platform Minikube runs inside:
  - `docker` (recommended, and the usual choice on Windows/Mac)
  - `hyperv` (Windows; needs an Administrator shell)
  - `virtualbox`, `kvm2`, `podman`, `qemu`
- `kubectl` (optional — Minikube ships its own, see below)

### 10.4 Essential Commands

**Start / stop / reset**

```bash
minikube start                        # start with the default driver
minikube start --driver=docker        # pick a driver explicitly
minikube start --cpus=4 --memory=4096 # give it more resources
minikube start --kubernetes-version=v1.30.0

minikube status                       # is it running?
minikube stop                         # shut down, keep all state
minikube delete                       # destroy the cluster completely
minikube delete --all                 # destroy every profile
```

**Talking to the cluster**

`minikube start` automatically writes the cluster into your kubeconfig, so plain `kubectl` just works:

```bash
kubectl get nodes
kubectl get pods -A
```

If you don't have `kubectl` installed, use the bundled one (note the `--`):

```bash
minikube kubectl -- get pods -A
```

**Dashboard and addons**

```bash
minikube dashboard                    # opens the web UI in your browser

minikube addons list
minikube addons enable ingress
minikube addons enable metrics-server
minikube addons disable dashboard
```

**Reaching your applications**

This is the part that trips people up on a local cluster:

```bash
minikube service <service-name>       # opens a NodePort Service in the browser
minikube service <service-name> --url # just print the URL

minikube tunnel                       # gives type=LoadBalancer Services an
                                      # external IP; run it in a separate
                                      # terminal, needs admin/sudo, keep running

minikube ip                           # the cluster's IP address
```

**Using your own locally built images**

A Minikube cluster has its **own** image store, separate from your host Docker. An image you just built locally is not visible to it, so Kubernetes goes looking on Docker Hub and fails with `ErrImagePull`. Two fixes:

```bash
# Option 1: push the image into Minikube
docker build -t myapp:v1 .
minikube image load myapp:v1
```

```bash
# Option 2 (Linux / Mac / Git Bash): build straight inside Minikube's Docker
eval $(minikube docker-env)
docker build -t myapp:v1 .
```

On Windows PowerShell, Option 2 looks like this:

```powershell
& minikube -p minikube docker-env --shell powershell | Invoke-Expression
docker build -t myapp:v1 .
```

Then set `imagePullPolicy: Never` (or `IfNotPresent`) in your Pod spec so Kubernetes uses the local image instead of pulling.

**Other useful commands**

```bash
minikube ssh                          # shell into the Minikube node
minikube start --nodes=3              # start a 3-node cluster
minikube node add                     # add a node to a running cluster
minikube profile list                 # list independent clusters
minikube start -p dev                 # start a named profile "dev"
minikube logs                         # cluster logs, for debugging
minikube mount /host/path:/vm/path    # share a host folder into the cluster
```

### 10.5 Minikube vs Other Local Options

| Tool | Runs in | Notes |
|------|---------|-------|
| **Minikube** | VM or container | Most feature-rich; good addons (ingress, dashboard, LoadBalancer via tunnel) |
| **kind** | Docker containers | "Kubernetes in Docker" — very fast, popular in CI |
| **k3s / k3d** | Lightweight binary / Docker | Small footprint, good for edge and IoT |
| **Docker Desktop** | Built in | One checkbox to enable Kubernetes; least configurable |

### 10.6 Minikube Limitations (Don't Use It in Production)

- Single machine, so no real high availability — if your laptop dies, the cluster dies
- Limited by your local CPU and RAM
- No real cloud LoadBalancer (you need `minikube tunnel`)
- Cloud features (cloud-controller-manager, cloud storage classes) are simulated or absent

**Rule of thumb:** learn and develop on Minikube; deploy to EKS / GKE / AKS or a self-managed cluster in production.

---

## Quick Recap

| Component | Where it runs | Job |
|-----------|---------------|-----|
| **etcd** | Control Plane | Stores all cluster state |
| **kube-apiserver** | Control Plane | Entry point; the only component that talks to etcd |
| **kube-scheduler** | Control Plane | Decides which node a Pod goes on |
| **kube-controller-manager** | Control Plane | Reconciles actual state toward desired state |
| **cloud-controller-manager** | Control Plane (cloud only) | Talks to the cloud provider's API |
| **kubelet** | Every node | Makes sure this node's Pods are running |
| **kube-proxy** | Every node | Routes Service traffic to Pods |
| **CNI plugin** | Every node | Pod networking and NetworkPolicy enforcement |
| **Container runtime** | Every node | Actually runs the containers (via CRI) |
