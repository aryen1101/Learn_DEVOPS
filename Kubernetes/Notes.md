# Kubernetes Notes

## Table of Contents

1. [Orchestration: Why We Need It](#1-orchestration-why-we-need-it)
2. [Docker Swarm](#2-docker-swarm)
3. [What is Kubernetes?](#3-what-is-kubernetes)
4. [Cluster Architecture](#4-cluster-architecture)
5. [Control Plane Components](#5-control-plane-components)
6. [Worker Node Components](#6-worker-node-components)
7. [Container Runtime & CRI](#7-container-runtime--cri)
8. [Core Concepts: Pods and Nodes](#8-core-concepts-pods-and-nodes)
9. [Desired State vs Actual State](#9-desired-state-vs-actual-state)
10. [Minikube](#10-minikube)
11. [Manifests, Labels, Selectors & Namespaces](#11-manifests-labels-selectors--namespaces)
12. [Core Kubernetes Objects](#12-core-kubernetes-objects)
13. [Kubernetes Services](#13-kubernetes-services)
14. [Deployment Strategies](#14-deployment-strategies)
15. [Pod Lifecycle & Health Probes](#15-pod-lifecycle--health-probes)
16. [ConfigMap & Secret](#16-configmap--secret)
17. [Cluster DNS: CoreDNS & FQDN](#17-cluster-dns-coredns--fqdn)
18. [Troubleshooting](#18-troubleshooting)
19. [kubectl Command Reference](#19-kubectl-command-reference)
20. [ConfigMap, Secret & Ingress (Session 12)](#20-configmap-secret--ingress-session-12)

---

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

How Services use kube-proxy, and the five Service types, are covered in [13](#13-kubernetes-services).

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

## 8. Core Concepts: Pods and Nodes

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

> These two get confused a lot. An init container finishes and exits; a sidecar keeps running. See [15.4](#154-init-containers) for YAML.

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

This is the core loop of Kubernetes. Example: a Deployment whose `replicas` field is set to 3.

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

## 11. Manifests, Labels, Selectors & Namespaces

### 11.1 Anatomy of a Manifest

Every Kubernetes object is described by the same four top-level fields:

For example, a Deployment manifest declares `apiVersion: apps/v1`, `kind: Deployment`, a `metadata` block holding the name `nginx-deployment` and a label such as `app: nginx`, and a `spec` block with `replicas: 3` plus the Pod template. Only the contents of `spec` change from kind to kind; the outer shape is always the same.

| Field | Purpose |
|-------|---------|
| `apiVersion` | `v1` for core objects (Pod, Service, ConfigMap, Secret, Namespace); `apps/v1` for Deployment, ReplicaSet, DaemonSet, StatefulSet |
| `kind` | The object type |
| `metadata` | Name (unique per namespace per kind), namespace, labels, annotations |
| `spec` | What you want. Kubernetes fills in a separate `status` field with what actually is |

Not sure what a field does? Ask the API itself:

```bash
kubectl explain pod.spec
kubectl explain pod.spec.containers
kubectl explain deployment.spec.strategy
```

### 11.2 `create` vs `apply`

Both take a manifest, but they behave differently when the object already exists:

| | `kubectl create -f file.yml` | `kubectl apply -f file.yml` |
|--|-----------------------------|-----------------------------|
| Object does not exist | Creates it | Creates it |
| Object already exists | **Error:** `AlreadyExists` | **Updates** it to match the file |
| Style | Imperative — "do this now" | Declarative — "make it look like this" |
| Tracks previous config | No | Yes (`last-applied-configuration` annotation), so it can compute diffs |
| Use it for | One-off scaffolding, `--dry-run` YAML generation | Everything you keep in Git; safe to re-run |

**Rule:** use `apply` for manifests you manage as files. Use `create` mainly to generate YAML:

```bash
kubectl create deployment nginx --image=nginx --dry-run=client -o yaml > deployment.yml
```

> Mixing them causes pain: an object created with `create` has no last-applied annotation, so the first `apply` on it can produce a confusing merge. Pick `apply` and stay with it.

### 11.3 Labels vs Selectors

**Labels** are key/value tags you put *on* an object. **Selectors** are queries that *find* objects by their labels. Labels are the glue that connects controllers, Services, and Pods — Kubernetes never links objects by name.

Where they live:

| | Labels | Selectors |
|--|--------|-----------|
| Location in the manifest | `metadata.labels` of the object (a Pod, a Deployment, a Node...) | `spec.selector` of the object that wants to *find* other objects |
| Shape | Flat key/value map, e.g. `app: myapp`, `tier: backend`, `env: prod` | Controllers (Deployment, ReplicaSet, DaemonSet, StatefulSet) use `matchLabels` (exact match) and optionally `matchExpressions` (`In`, `NotIn`, `Exists`). A **Service** uses a plain flat map with no `matchLabels` |
| Direction | Describes *this* object | Points *at other* objects (always Pods, in the cases above) |

How the pieces connect:

```
Deployment (selector: app=myapp)
      |
      +--> ReplicaSet (selector: app=myapp)
                |
                +--> Pod  (labels: app=myapp)   <--+
                +--> Pod  (labels: app=myapp)   <--+-- Service (selector: app=myapp)
                +--> Pod  (labels: app=myapp)   <--+
```

Rules that bite:

- The Pod `template.metadata.labels` **must satisfy** the controller's `selector`, or the API Server rejects the manifest (`selector does not match template labels`).
- A Service's selector matches **Pod labels**, not the Deployment's name. If the Service shows no endpoints, this is the first thing to check.
- A Deployment's `spec.selector` is **immutable** after creation. To change it you must delete and recreate the Deployment.
- Labels are also how *you* filter with `kubectl`:

```bash
kubectl get pods -l app=myapp                # equality
kubectl get pods -l 'env in (dev,staging)'   # set-based
kubectl get pods -l app=myapp,tier=backend   # AND
kubectl get pods --show-labels
kubectl label pod <pod> env=prod             # add / change a label
kubectl label pod <pod> env-                 # remove a label
```

A **selector-mismatch drill** (see `Kubernetes_Objects/troubleshooting/selector-mismatch.yaml`): change a label in the Pod template so it no longer matches `selector.matchLabels` and apply it. The API Server refuses it immediately — useful to see that this is validated *before* anything is stored.

### 11.4 Namespaces

A **Namespace** is a virtual cluster inside the cluster — a way to divide resources between teams, environments, or apps. Names only have to be unique *within* a namespace.

Default namespaces:

| Namespace | Contents |
|-----------|----------|
| `default` | Where your objects land if you don't specify one |
| `kube-system` | Control plane components, kube-proxy, CoreDNS, CNI |
| `kube-public` | Readable by everyone, rarely used |
| `kube-node-lease` | Node heartbeat leases |

```bash
kubectl get ns
kubectl create ns dev
kubectl get pods -n dev                                  # look in one namespace
kubectl get pods -A                                      # look in all namespaces
kubectl config set-context --current --namespace=dev     # make dev the default
kubectl delete ns dev                                    # deletes EVERYTHING inside it
```

Or pin it in the manifest by setting `metadata.namespace: dev`; every `kubectl apply` of that file then lands in `dev` without needing `-n`.

> Some objects are **cluster-scoped**, not namespaced: Node, Namespace, PersistentVolume, StorageClass, ClusterRole. `kubectl api-resources --namespaced=false` lists them.

Cross-namespace DNS for Services: `<service>.<namespace>.svc.cluster.local` — how that name is built and resolved is in [17](#17-cluster-dns-coredns--fqdn).

---

## 12. Core Kubernetes Objects

### 12.1 Pod

Smallest deployable unit. One or more containers sharing an IP, ports, and volumes.

A minimal Pod manifest has `apiVersion: v1`, `kind: Pod`, a `metadata` block with a name and labels, and under `spec.containers` a list with one entry: the container's `name`, its `image` (for example `nginx:latest`) and the `containerPort` the process listens on (80 for nginx).

A **multi-container Pod** simply lists two entries under `spec.containers`, for example an `nginx` app container and a `busybox` logging sidecar running a small loop command. They share `localhost` and any volumes declared on the Pod.

**`restartPolicy`** — what the kubelet does when a container exits:

| Value | Behaviour | Use for |
|-------|-----------|---------|
| `Always` (default) | Restart no matter how it exited | Long-running servers |
| `OnFailure` | Restart only on a non-zero exit | Retryable batch work |
| `Never` | Never restart | One-shot tasks |

A **run-once Pod** is a `busybox` container whose `command` echoes a message and exits, with `restartPolicy: Never` set at the Pod level. Without that field it would print, exit, and be restarted forever (`CrashLoopBackOff`).

**Resource requests and limits** live under each container's `resources` block. They tell the Scheduler what a container needs and cap what it may use:

| Field | Who uses it | Example | Meaning |
|-------|-------------|---------|---------|
| `resources.requests.cpu` | Scheduler | `250m` | 0.25 CPU guaranteed; the node must have this much free |
| `resources.requests.memory` | Scheduler | `128Mi` | Memory the Pod is assumed to need |
| `resources.limits.cpu` | kubelet / runtime | `500m` | Hard cap; the container is **throttled** above it |
| `resources.limits.memory` | kubelet / runtime | `256Mi` | Hard cap; exceeding it gets the container **OOMKilled** |

`m` means milli-CPU (1000m = 1 core); `Mi`/`Gi` are mebibytes/gibibytes. Requests decide *placement*; limits decide *enforcement*. A container with limits equal to its requests gets the `Guaranteed` QoS class and is the last to be evicted under memory pressure.

If no node has enough free capacity for the **requests**, the Pod stays `Pending` forever (see `pod-lifecycle/02-pending.yaml`, which asks for 1000 CPUs).

> **You cannot scale a Pod.** A Pod has no `replicas` field — it *is* one instance. "Scaling" means creating more Pods, which is a controller's job (ReplicaSet / Deployment).
>
> A bare Pod is not self-healing either. Delete it, or lose its node, and it is gone. Use a controller for anything real.

### 12.2 ReplicaSet

Keeps exactly N identical Pods running. This is the object that does the self-healing.

A ReplicaSet manifest (`apiVersion: apps/v1`, `kind: ReplicaSet`) has three parts under `spec`:

- `replicas` — desired count
- `selector` — which Pods this ReplicaSet owns, matched by **label**
- `template` — the Pod spec; its labels must satisfy the selector or the API rejects it

```bash
kubectl scale rs nginx-rs --replicas=5
kubectl get rs                        # DESIRED / CURRENT / READY columns
```

> A ReplicaSet cannot do rolling updates. Change the image and the existing Pods stay on the old one — you would have to delete them by hand. That is why you use a Deployment.

### 12.3 Deployment

A ReplicaSet manager. Same fields as a ReplicaSet, plus versioning: rolling updates, rollback, history.

A Deployment manifest looks exactly like a ReplicaSet manifest (`apiVersion: apps/v1`, `kind: Deployment`, then `spec.replicas`, `spec.selector.matchLabels` and `spec.template`) with one optional extra: a `spec.strategy` block that says *how* to roll out changes. You never write the ReplicaSet yourself; the Deployment creates and names it (`<deployment>-<pod-template-hash>`).

On an image change the Deployment creates a **new** ReplicaSet and shifts Pods over gradually — old RS scales down, new RS scales up. The old one is kept at 0 replicas so `kubectl rollout undo` can reverse it.

```
Deployment -> ReplicaSet (v2, 3 pods)
           +- ReplicaSet (v1, 0 pods)   <- kept for rollback
```

**Update strategies**

`spec.strategy.type` is either `RollingUpdate` (the default) or `Recreate`. For RollingUpdate two tuning fields live under `spec.strategy.rollingUpdate`: `maxSurge` (how many **extra** Pods may exist during the update) and `maxUnavailable` (how many Pods may be **down** during the update).

| Strategy | Behaviour | Downtime |
|----------|-----------|----------|
| `RollingUpdate` (default) | Replace Pods a few at a time, controlled by `maxSurge` / `maxUnavailable` (numbers or percentages, default 25% each) | None |
| `Recreate` | Kill **all** old Pods, then create the new ones | Yes — use only when two versions cannot coexist (e.g. a DB schema change) |

With `maxSurge: 1, maxUnavailable: 0` a rollout is safest: one new Pod comes up, must become Ready, then one old Pod goes away. If the new image is broken (`ImagePullBackOff`), the rollout **stalls** but the old Pods keep serving — see `troubleshooting/broken-image.yaml` and [18.3](#183-rollout-failures--rollback).

```bash
kubectl set image deploy/nginx-deployment nginx=nginx:1.26   # trigger a rollout
kubectl rollout status  deploy/nginx-deployment
kubectl rollout history deploy/nginx-deployment
kubectl rollout undo    deploy/nginx-deployment              # previous revision
kubectl rollout undo    deploy/nginx-deployment --to-revision=1
kubectl rollout pause   deploy/nginx-deployment
kubectl rollout resume  deploy/nginx-deployment
kubectl rollout restart deploy/nginx-deployment              # rolling restart, same image
kubectl scale deploy nginx-deployment --replicas=5
```

> `kubectl rollout history` shows `CHANGE-CAUSE: <none>` unless you record one: `kubectl annotate deploy/nginx-deployment kubernetes.io/change-cause="upgrade to 1.26"`.

**Default choice for stateless apps.** The two built-in strategies above plus the Blue-Green and Canary patterns are covered in depth, with labs, in [14](#14-deployment-strategies).

### 12.4 Service

Pods get a new IP every time they are recreated, so you never talk to a Pod IP. A Service gives a **stable name and virtual IP** in front of a set of Pods (selected by label) and load-balances across them. It is the one core object in this list that is about *reaching* workloads rather than *running* them.

A Service manifest (`apiVersion: v1`, `kind: Service`) has three parts under `spec`:

| Field | Meaning |
|-------|---------|
| `type` | `ClusterIP` (default), `NodePort`, `LoadBalancer` or `ExternalName`; decides who can reach it |
| `selector` | A flat label map that matches **Pod labels**, never the Deployment's name |
| `ports` | One or more entries, each with `port` (the Service's own port), `targetPort` (the container port), optional `nodePort`, `protocol` and `name` |

Services are large enough a topic to get their own section: the five kinds, how traffic actually flows, the four different "port" fields and how to choose are all in [13](#13-kubernetes-services).

### 12.5 DaemonSet

Runs **one copy of a Pod on every node**, including any node added later. There is no `replicas` field — the node count is the replica count.

A DaemonSet manifest (`apiVersion: apps/v1`, `kind: DaemonSet`) has a `spec.selector` and a `spec.template` exactly like a ReplicaSet, but **no `replicas`**. A `nodeSelector` or `tolerations` inside the Pod template limit which nodes get a copy (for example only Linux nodes, or also the control-plane node, which is tainted by default).

Used for per-node agents: log collectors (Fluentd), metrics exporters, monitoring, CNI plugins, storage daemons.

```bash
kubectl get ds -A                          # kube-proxy and the CNI are DaemonSets in kube-system
```

### 12.6 StatefulSet

For stateful apps (databases, Kafka) where each Pod needs a **stable identity and its own storage**.

A StatefulSet manifest (`apiVersion: apps/v1`, `kind: StatefulSet`) adds two things to the familiar `replicas` / `selector` / `template` trio:

| Field | Purpose |
|-------|---------|
| `spec.serviceName` | Name of a **headless Service** (`clusterIP: None`) that must exist. It gives every Pod its own DNS record (see [13.8](#138-headless-service)) |
| `spec.volumeClaimTemplates` | A PVC blueprint. Kubernetes stamps out **one PersistentVolumeClaim per Pod** (for example 5Gi, `ReadWriteOnce`) and re-attaches the same claim to the same Pod name after a restart |
| `spec.template` | The usual Pod template; the container mounts the claim by name (a MySQL container would mount it at `/var/lib/mysql`) |
| `spec.podManagementPolicy` | `OrderedReady` (default: one Pod at a time, `-0` first) or `Parallel` |
| `spec.updateStrategy` | `RollingUpdate` in **reverse ordinal order**, or `OnDelete` |

How it differs from a Deployment:

| | Deployment | StatefulSet |
|--|-----------|-------------|
| Pod names | random (`myapp-7d9f-x2k`) | ordered (`mysql-0`, `mysql-1`, `mysql-2`) |
| Identity after restart | new name, new IP | **same name**, same storage |
| Storage | shared or none | one PVC per Pod via `volumeClaimTemplates` |
| Start / stop order | all at once | one at a time, in order (reverse on delete) |
| Service | optional | **requires** a headless Service (`serviceName`) |
| DNS per Pod | no | yes: `mysql-0.mysql.<ns>.svc.cluster.local` (see [17](#17-cluster-dns-coredns--fqdn)) |

> Passing a database root password as a plain `env` value in the template is fine for learning only; in reality that belongs in a **Secret** (see [16](#16-configmap--secret)).

### 12.7 Deployment vs ReplicaSet vs DaemonSet vs StatefulSet

All four are **workload controllers** in `apps/v1`. Each owns a set of Pods (matched by `selector`) and stamps them out from a `template`. They differ in *how many* Pods they run, *where* they run, and *what identity* the Pods get.

```
ReplicaSet   -> "keep N identical copies running"          (no update logic)
Deployment   -> ReplicaSet + versioning                     (rolling update, rollback, history)
DaemonSet    -> "one copy on every node"                    (node count = replica count)
StatefulSet  -> "N copies with stable names + own storage"  (ordered, one PVC per Pod)
```

**Deployment vs ReplicaSet vs DaemonSet**

| | ReplicaSet | Deployment | DaemonSet |
|--|-----------|------------|-----------|
| Purpose | Keep exactly N identical Pods alive | Manage ReplicaSets so you get versioned, zero-downtime updates | Run one Pod on **every** node (or every node matching a `nodeSelector`) |
| `replicas` field | Yes | Yes | **No** — the count follows the node count |
| Placement | Scheduler puts Pods wherever there is room | Same | One per node; a node added later automatically gets a Pod |
| Image change | Existing Pods keep the old image; you would delete them by hand | Creates a **new ReplicaSet**, shifts Pods over, keeps the old RS at 0 for rollback | Rolling update node by node (`updateStrategy: RollingUpdate`, the default) |
| Rollback / history | No | Yes — `kubectl rollout undo / history` | Yes — `kubectl rollout undo ds/<name>` |
| Do you create it yourself? | Rarely — the Deployment does | Yes | Yes |
| Typical use | Internal building block | Web apps, APIs, any stateless service | Log shippers (Fluentd), node metrics (node-exporter), CNI, kube-proxy, storage agents |

> A Deployment never runs Pods directly. Deployment -> ReplicaSet -> Pods. After a rollout `kubectl get rs` shows the previous ReplicaSet at `0` replicas; that is what `rollout undo` scales back up.

**Deployment vs DaemonSet vs StatefulSet**

| | Deployment | DaemonSet | StatefulSet |
|--|-----------|-----------|-------------|
| How many Pods | `replicas: N`, anywhere | One per node | `replicas: N`, anywhere |
| Pod names | Random (`web-7d9f8c-x2k9q`) | Random (`agent-k4l2p`) | Ordered and predictable (`db-0`, `db-1`, `db-2`) |
| Identity after restart | New name, new IP | New name, but always back on the same node | **Same name**, same PVC, same DNS record |
| Storage | Shared volume or none; all Pods identical | Usually `hostPath` on its own node | One PVC per Pod via `volumeClaimTemplates`; the PVC outlives the Pod |
| Start / stop order | All at once | As nodes appear | One at a time, `-0` first; reverse order on scale-down |
| Service | Any type, optional | Usually none (reached via node IP / `hostPort`) | **Requires** a headless Service (`clusterIP: None`, set in `serviceName`) |
| Per-Pod DNS | No | No | Yes: `db-0.db.<ns>.svc.cluster.local` (see [17](#17-cluster-dns-coredns--fqdn)) |
| Scaling | `kubectl scale` freely | Add or remove nodes | `kubectl scale`, ordered; scaling down does **not** delete the PVCs |
| Use for | Stateless: frontends, APIs, workers | Per-node agents | Databases, Kafka, ZooKeeper, Redis cluster — anything where "which replica am I" matters |

**Quick rules**

- Interchangeable Pods behind a load balancer -> **Deployment**.
- Must run on every node -> **DaemonSet**.
- Each Pod needs its own disk and a stable name its peers can find -> **StatefulSet**.
- A bare **ReplicaSet** -> almost never; let a Deployment own it.

Lab: `Kubernetes_Objects/k8s-core-objects/` has one manifest per kind; `daemonset/node-agent-ds.yaml` and `replicaset/backend-rs.yaml` are the standalone examples.

### 12.8 Which Object to Use

| Need | Object |
|------|--------|
| Test a single container | Pod |
| N identical Pods, self-healing | ReplicaSet (rarely used directly) |
| Stateless app with rolling updates | **Deployment** |
| One Pod per node (agent) | DaemonSet |
| Database / stable identity + storage | StatefulSet |
| Stable network address for Pods | Service |
| Run-to-completion task | Job (and CronJob for a schedule) |
| Non-secret config injected into Pods | ConfigMap |
| Passwords, tokens, certs | Secret |

---

## 13. Kubernetes Services

### 13.1 Why Services Exist

Pods are mortal. They crash, get rescheduled to another node, are replaced during a rollout, and are scaled up and down. **Every new Pod gets a new IP address.** If a frontend is configured to call a backend at its Pod IP, the first time that Pod is recreated the frontend starts returning `Connection Refused` or `502 Bad Gateway`.

There is a second problem: a Deployment with three replicas has three IPs. Which one should the caller use, and who spreads the load?

A **Service** solves both. It is a stable, cluster-managed **virtual IP and DNS name** that sits in front of a *set* of Pods chosen by label. Callers talk to the Service; Kubernetes keeps track of which Pods are behind it right now and forwards each connection to a healthy one.

Analogy: an office with five support agents who rotate shifts and change desks. You do not call an agent's personal phone; you dial the billing extension. The switchboard routes the call to whoever is logged in right now. The extension is the Service, the switchboard is kube-proxy plus the endpoint list, and the agents are the Pods.

### 13.2 How a Service Works

A Service is only an API object with a selector and some port numbers. Three other components turn it into working networking:

```
Client Pod                       CoreDNS                 API Server / etcd
   | 1. resolve "backend"  ---->  returns 10.96.45.12      Service object: selector app=backend
   |                                                        EndpointSlice: 10.244.0.12:80,
   | 2. connect 10.96.45.12:80                                             10.244.1.18:80, 10.244.2.33:80
   v
kube-proxy rule on THIS node:  10.96.45.12:80  ->  pick one of the three Pod IP:port pairs
   |
   v
Backend Pod (10.244.1.18:80)
```

1. **Allocation.** When the Service is created, the API Server gives it a **ClusterIP** from the *service* address range (for example `10.96.0.0/12`). This range is separate from the *Pod* range (for example `10.244.0.0/16`). The ClusterIP is virtual: no network interface anywhere owns it, so you cannot ping it; you can only connect to its ports.
2. **Endpoint tracking.** The EndpointSlice controller (inside the Controller Manager) watches Pods. Every Pod whose labels match the selector **and** whose readiness probe passes is written into an **EndpointSlice** as `IP:targetPort`. A Pod that turns Not Ready, or starts Terminating, is removed immediately. The older `Endpoints` object still exists and is what `kubectl get endpoints` shows.
3. **Forwarding.** kube-proxy on **every node** watches Services and EndpointSlices and programs the node's iptables (or IPVS) rules. A packet sent to `ClusterIP:port` is rewritten to one backend `PodIP:targetPort`. Selection is per **connection**, roughly random, not per HTTP request. This is Layer 4 (TCP/UDP/SCTP): kube-proxy knows nothing about URLs, headers or cookies.
4. **Naming.** CoreDNS creates an A record `<service>.<namespace>.svc.cluster.local` pointing at the ClusterIP, so callers use the name and never see the IP (details in [17](#17-cluster-dns-coredns--fqdn)).

Two consequences worth remembering:

- **Readiness gates traffic.** A Pod can be `Running` and still receive nothing because its readiness probe fails; it is simply not in the endpoint list. This is what makes rolling updates safe.
- **A Service with no matching Pods still exists** and still resolves in DNS. Connections just fail. An empty endpoint list is therefore the first thing to check when a Service "does not work" ([18.4](#184-service-not-reachable)).

### 13.3 The Four Kinds of "Port"

There are four different port fields, on two different objects, and mixing them up is the most common Service mistake.

| Field | Lives on | Meaning |
|-------|----------|---------|
| `containerPort` | Pod (container spec) | The port the **application inside the container** listens on. Mostly documentation; it does not publish anything by itself |
| `targetPort` | Service | The Pod port the Service **forwards to**. Must be the port the app really listens on. Can be a number or the *name* of a container port |
| `port` | Service | The port the **Service itself** listens on. Other Pods call `http://<service>:<port>` |
| `nodePort` | Service (`NodePort` and `LoadBalancer` only) | The port opened on **every node's IP**, range 30000–32767. Auto-assigned if omitted |

Traffic from **outside** the cluster through a NodePort:

```
Browser
   |  <Node-IP>:30080          (nodePort)
   v
Service :80                    (port)
   |  forwards to :8080        (targetPort)
   v
Pod
 +-- App listening on :8080    (containerPort)
```

Traffic from **another Pod** inside the cluster (ClusterIP path; nodePort is not involved):

```
Other Pod
   |  http://my-service:80     (port)
   v
Service :80
   |  forwards to :8080        (targetPort)
   v
Pod :8080                      (containerPort)
```

Rules of thumb:

- If `targetPort` is omitted it defaults to `port`. An app on 80 behind a Service on 80 needs nothing else.
- A Service can expose **several ports** (HTTP and metrics, for example). Then every entry needs a `name`.
- Using a **named** `targetPort` (the container declares `name: http` on its port, the Service says `targetPort: http`) lets you change the container's port number without touching the Service.
- `protocol` defaults to `TCP`; `UDP` and `SCTP` are also valid.

### 13.4 ClusterIP

**What it is.** The default type. The Service gets a virtual IP from the service range and a DNS name, and is reachable **only from inside the cluster**. Nothing outside can route to a `10.96.x.x` address.

**The problem it solves.** Internal callers need a stable address for a moving set of Pods. ClusterIP is exactly that and nothing more.

**Where it is used.**
- Microservice-to-microservice calls: the payment service calling the order service.
- Databases, caches and queues that run inside the cluster and must never be reachable from the internet: PostgreSQL, MySQL, Redis, MongoDB, RabbitMQ.
- Internal dashboards, metrics collectors, log aggregators.
- **Behind an Ingress controller.** The controller receives external traffic and forwards it to ClusterIP Services; the Services themselves stay internal.

**Key fields.** `type: ClusterIP` (or simply omitted), a `selector`, and `ports` with `port` (the front door other Pods use) and `targetPort` (the back door on the container). A Service on port 8080 in front of nginx containers listening on 80 is a perfectly normal combination: callers use 8080, the Pods never know.

**Reaching it from your laptop anyway.** Two options, both bypassing the "internal only" rule for debugging: port-forward the Service to a local port (see [19.6](#196-port-forwarding)), or run a throwaway client Pod inside the cluster and call the Service from there. That second method is also how you prove DNS works: the short name, the full FQDN and the raw ClusterIP must all answer.

**Pitfalls.** Empty endpoints means the selector does not match the Pod labels. Connection refused with non-empty endpoints means `targetPort` is not the port the process listens on. Name does not resolve means CoreDNS is unhealthy or the caller is in another namespace and used the short name.

### 13.5 NodePort

**What it is.** The simplest native way to let traffic from **outside** the cluster in. Setting `type: NodePort` makes Kubernetes:

1. Create a ClusterIP as usual (a NodePort Service *contains* a ClusterIP Service).
2. Pick a port from the range **30000–32767** (or use the one you set in `nodePort`).
3. Open that same port on **every node** in the cluster, whether or not the node runs one of the Pods.

A request to `http://<any-node-IP>:<nodePort>` is caught by kube-proxy on that node, sent to the Service's ClusterIP, and from there to one backend Pod, even one on a different node.

```
External client
      |  http://192.168.49.2:30080
      v
Node 192.168.49.2  :30080   (nodePort)      <- the same port is open on every node
      |
      v
Service ClusterIP 10.96.210.44 :80   (port)
      |
      +----> Pod 10.244.0.15 :80   (targetPort)
      +----> Pod 10.244.0.16 :80
```

Analogy: a hotel. The street gate is the `nodePort`, the lobby desk is the Service `port`, the room door is the `targetPort`. Whether you enter through the north gate (node 1) or the south gate (node 2) you end up at the same rooms.

**Where it is used.**
- On-premise and bare-metal clusters that have no cloud API to create a load balancer.
- Development and staging on Minikube, kind, k3s, MicroK8s.
- Exposing an **Ingress controller** on fixed ports (30080/30443) that a hardware load balancer or router forwards to.
- Raw TCP/UDP protocols and legacy systems that need a known host port.

**Reading the output.** `kubectl get svc` shows `80:30080/TCP` for a NodePort Service: the first number is the internal `port`, the second is the `nodePort`.

**Reaching it on Minikube.** The node IP is what `minikube ip` prints. With the Docker driver on macOS and Windows that IP is not routable from the host, so `minikube service <name>` opens a tunnel and prints a working URL instead.

**Limitations.**
1. **Port range.** You cannot serve on 80 or 443 without changing the API Server flag `--service-node-port-range`.
2. **One Service per port.** Two Services cannot both claim 30080.
3. **No high availability by itself.** Clients that connect to one node's IP lose service when that node dies unless something in front spreads traffic across all node IPs.
4. **Security exposure.** The port is open on every node, so firewall and security-group rules must be managed deliberately.
5. **Extra hop and lost source IP.** By default (`externalTrafficPolicy: Cluster`) a node may forward the packet to a Pod on another node and rewrite the source address. `externalTrafficPolicy: Local` keeps the client IP and avoids the hop, but only nodes that actually run a Pod will answer.

### 13.6 LoadBalancer

**What it is.** The standard way to expose an internet-facing application in a managed cloud (EKS, GKE, AKS, DigitalOcean). Setting `type: LoadBalancer` makes the **cloud-controller-manager** ask the cloud for a real, managed load balancer (AWS NLB or Classic ELB, GCP Network LB, Azure Public LB). The cloud hands back a **public IP or DNS name**, which appears in the `EXTERNAL-IP` column after a minute or two. Underneath, Kubernetes creates a NodePort *and* a ClusterIP: the cloud LB sends traffic to the node ports, and from there the normal path applies.

```
Internet user  -->  Cloud load balancer (public IP :80)
                        |  health-checks every node, spreads traffic across them
                        +--> Node 1 :31250 (nodePort) --+
                        +--> Node 2 :31250 (nodePort) --+--> ClusterIP :80 --> Pods :80
```

**The problems with NodePort it fixes.** Users will not type `:30080`; they expect 80 and 443. A single node IP is a single point of failure. Nothing balances across availability zones. The cloud LB gives one resilient entry point with health checks and standard ports.

Analogy: the international terminal of an airport. Every traveller enters through the same doors (the LB), shuttles move them between concourses (the nodes), and they end up at their gate (the Pod).

**Where it is used.** Public web frontends, public REST/GraphQL APIs, webhooks. And, in most real architectures, exactly **one** LoadBalancer in front of an **Ingress controller**, with everything else behind it as ClusterIP.

**Cost.** Every LoadBalancer Service is a separate cloud resource, roughly 18–25 USD per month on AWS. Fifty microservices with fifty LoadBalancers is over a thousand dollars a month before any traffic. The usual design is one LB, one Ingress controller, and Ingress rules routing by hostname (`api.company.com`, `app.company.com`) or path (`/orders`, `/users`) to internal ClusterIP Services.

**On a local cluster.** Minikube has no cloud provider, so `EXTERNAL-IP` stays `<pending>` forever. `minikube tunnel` (run in its own terminal, needs admin rights) simulates the cloud and assigns an address; `minikube service <name>` is the quicker alternative. On bare metal, **MetalLB** plays the cloud's role and hands out IPs from a pool you define.

**Layer 4 versus Layer 7.** A LoadBalancer Service is still L4: it balances connections. It cannot route by URL, terminate TLS per hostname or do path rewrites. That is the job of an **Ingress** (or the newer Gateway API), which is not a Service type but a separate object that an Ingress controller implements.

### 13.7 ExternalName

**What it is.** A Service with **no selector, no Pods and no ClusterIP**. Instead of programming kube-proxy, it makes CoreDNS return a **CNAME** record: a query for the Service name is answered with an external hostname such as `db.example.com` or `api.github.com`. The Pod then connects to that external host directly; no cluster networking is involved beyond DNS.

```
App Pod  --"external-database-service?"-->  CoreDNS
App Pod  <--CNAME api.github.com------------  CoreDNS
App Pod  ------------------------------------------------>  api.github.com (outside the cluster)
```

**The problem it solves.** Hard-coded external URLs. The database is `dev-db.local` in development, `staging-postgres.company.internal` in staging and a long RDS hostname in production. If twenty microservices embed those names, a migration means rebuilding twenty images. With an ExternalName Service every app connects to the same internal name, and switching the target is a one-line change to the Service, with no code change and no redeploy.

Analogy: a speed-dial entry called "Best Friend". When the friend changes carriers you update the number behind the nickname; your habit of pressing the same button does not change.

**Where it is used.**
- Managed databases outside the cluster: AWS RDS, Cloud SQL, MongoDB Atlas.
- Third-party APIs (Stripe, Twilio, SendGrid) under an internal naming convention.
- Gradual migration: Pods talk to a legacy VM through an ExternalName alias until the monolith is containerised, then the alias is repointed.

**Key fields.** `type: ExternalName` and `externalName: <hostname>`. No selector and no `targetPort`; `ports` may be listed for documentation but are not used for routing. `kubectl get svc` shows `CLUSTER-IP <none>` and the hostname in `EXTERNAL-IP`.

**Caveats.**
- **DNS only.** Nothing can be remapped: port 80 stays port 80 because kube-proxy is not in the path.
- **TLS breaks unless you use the real name.** The external server's certificate is for `api.github.com`, not for `external-database-service`. Clients must send the real hostname as the SNI and `Host` header, or trust checks fail. In practice this makes ExternalName more useful for databases and plain TCP than for HTTPS APIs.
- **Hostnames only, no IP addresses.** To alias a raw external IP, create a normal ClusterIP Service **without a selector** and add an `Endpoints`/`EndpointSlice` object by hand that lists the IP (see [13.9](#139-other-service-settings-worth-knowing)).
- Cross-namespace aliasing is a common trick: an ExternalName in namespace `a` pointing at `svc.b.svc.cluster.local` gives namespace `a` a local name for a Service in `b`.

### 13.8 Headless Service

**What it is.** A Service with `clusterIP: None`. Kubernetes allocates **no virtual IP**, kube-proxy programs **no rules**, and a DNS lookup of the Service name returns the **IP addresses of all matching Pods** as individual A records. The client, not kube-proxy, decides which Pod to talk to. `kubectl get svc` still shows `TYPE ClusterIP` but `CLUSTER-IP None`.

| | Regular Service | Headless Service (`clusterIP: None`) |
|--|-----------------|--------------------------------------|
| Virtual IP | Allocated (`10.96.140.50`) | None |
| Load balancing | kube-proxy, per connection | The client or the application library |
| DNS answer for the Service name | One IP: the ClusterIP | Every ready Pod IP |
| DNS name per Pod | No | Yes, with a StatefulSet: `<pod>.<service>.<namespace>.svc.cluster.local` |
| Typical workload | Stateless Deployments | StatefulSets: databases, brokers, quorum systems |

**The problem it solves.** Clustered systems care *which* replica they reach. In a MySQL or PostgreSQL primary/replica setup, Pod 0 accepts writes and Pods 1 and 2 are read-only; a regular Service would send a write to a replica and the transaction would fail. Kafka brokers, ZooKeeper and etcd members must find each other **by name** to form a quorum and elect a leader. Round-robin to "any Pod" is exactly wrong for these.

```
Regular:  client asks "db"          -> CoreDNS: 10.96.0.50        -> kube-proxy picks a Pod
Headless: client asks "db"          -> CoreDNS: 10.244.0.10, 10.244.0.11, 10.244.0.12   (client picks)
          client asks "db-0.db"     -> CoreDNS: 10.244.0.10                              (exactly Pod 0)
```

Analogy: a company directory versus a switchboard. The switchboard (regular Service) connects you to whichever operator is free. The directory (headless Service) lists every engineer's desk extension so you can dial Alice directly.

**How it pairs with a StatefulSet.** The StatefulSet's `serviceName` must name the headless Service. Kubernetes then publishes a stable DNS record per ordinal Pod: `web-0.web.default.svc.cluster.local`, `web-1.web...`, and so on. When `web-0` is recreated it gets a new IP, but the *name* stays, and DNS is updated, which is what "stable network identity" means in [12.6](#126-statefulset).

**Where it is used.**
- Quorum clusters: Kafka, ZooKeeper, etcd, RabbitMQ, Cassandra.
- Primary/replica databases: MySQL and PostgreSQL replication, MongoDB replica sets.
- Client-side load balancing: gRPC and Envoy resolve all Pod IPs once and balance themselves, keeping long-lived connections to each.
- Redis Cluster and Redis Sentinel topologies.

**Caveats.** Because there is no VIP, clients must re-resolve DNS when a Pod is replaced; libraries that cache an IP forever will keep talking to a dead Pod. A headless Service *without* a selector publishes nothing unless you create the endpoints by hand. Only **ready** Pods appear in the answer unless `publishNotReadyAddresses` is set, which some clustered databases need so members can find each other before they are healthy.

### 13.9 Other Service Settings Worth Knowing

| Setting | What it does | When |
|---------|--------------|------|
| `sessionAffinity: ClientIP` | Sends every connection from the same client IP to the same Pod for a period (default 3 hours) | Sticky sessions for apps that keep state in memory. Prefer fixing the app |
| `externalTrafficPolicy: Local` | For NodePort/LoadBalancer: only forward to Pods on the receiving node; preserves the client's real source IP | When the app needs the caller's IP, or to avoid the extra node-to-node hop |
| `internalTrafficPolicy: Local` | Same idea for in-cluster traffic | Node-local caches and agents |
| Service **without a selector** | No endpoints are managed for you; you create an `Endpoints`/`EndpointSlice` object listing IPs yourself | Pointing a cluster name at an external IP, or at a database in another cluster |
| `publishNotReadyAddresses` | Include Not Ready Pods in headless DNS answers | Peer discovery in StatefulSet databases |
| `allocateLoadBalancerNodePorts: false` | Skip the automatic NodePort for a LoadBalancer Service | Cloud LBs that talk to Pods directly |
| `loadBalancerSourceRanges` | Only these CIDRs may reach the LoadBalancer | Restricting a public LB to office IPs |

### 13.10 Comparison and Choosing

The types are layered: a LoadBalancer is a NodePort plus a cloud LB, and a NodePort is a ClusterIP plus an open port on every node. ExternalName and headless stand apart because they are DNS tricks rather than proxies.

| Type | Reachable from | Gets a ClusterIP | Needs a selector | kube-proxy involved | Typical use |
|------|----------------|------------------|------------------|---------------------|-------------|
| `ClusterIP` | Inside the cluster only | Yes | Yes | Yes | Service-to-service traffic, databases, anything behind an Ingress |
| `NodePort` | `<node-IP>:30000-32767` | Yes | Yes | Yes | Bare metal, local dev, exposing an Ingress controller on fixed ports |
| `LoadBalancer` | Public IP / DNS on standard ports | Yes | Yes | Yes | Internet-facing apps in the cloud; usually one, in front of Ingress |
| `ExternalName` | Inside (as a DNS alias to outside) | No | No | No | Managed DBs, third-party APIs, migrations |
| Headless (`clusterIP: None`) | Inside, per Pod | No | Usually | No | StatefulSets, quorum systems, client-side balancing |

Choosing:

- Internal only -> **ClusterIP**. This is the answer 90% of the time.
- Need to reach it from a laptop or a bare-metal LAN, and a high port is acceptable -> **NodePort**.
- Public users on port 80/443 in a cloud -> **LoadBalancer**, and put an **Ingress controller** behind it instead of one LB per app.
- The thing you want to reach lives *outside* the cluster -> **ExternalName** (hostname) or a selector-less Service with manual endpoints (raw IP).
- Clients must address individual Pods, or the Pods must discover each other -> **headless Service**, almost always together with a StatefulSet.

Labs with the manifests and step-by-step commands for each type live in `Kubernetes_Services/01-clusterip/` through `05-headless/`; each folder's README walks through deploying, testing from inside the cluster, and the expected output.

---

## 14. Deployment Strategies

A **deployment strategy** is *how* you move running Pods from version v1 to v2. The choice decides three things:

1. **Downtime** — is there ever a moment with zero Pods serving?
2. **Mixed traffic** — do v1 and v2 serve users at the same time (matters for DB schema changes and API compatibility)?
3. **Blast radius and rollback** — how many users see a bad release, and how fast can you go back?

Kubernetes has **two built-in** strategies on `Deployment.spec.strategy`: `RollingUpdate` and `Recreate`. **Blue-Green** and **Canary** are not fields; they are *patterns* you build from two Deployments plus a Service (selector switch or replica ratio).

```
Built-in (spec.strategy)            Patterns (2 Deployments + 1 Service)
-------------------------           ------------------------------------
RollingUpdate  (default)            Blue-Green  -> flip the Service selector
Recreate                            Canary      -> control the Pod count ratio
```

Restaurant mental model:

- **Rolling Update** — renovate room by room while the restaurant stays open; customers are seated at whatever tables are free.
- **Blue-Green** — build a new restaurant across the street; when it is ready, redirect everyone in one move.
- **Canary** — open a small tasting counter with the new menu for 10% of customers before changing the main menu.
- **Recreate** — hang a sign "Closed 2–5 PM for renovation", gut the interior, reopen.

Labs: `Kubernetes_Objects/01-rolling-update/`, `02-blue-green/`, `03-canary/`, `04-recreate/` — each has a README with the full walkthrough and expected output. Every lab exposes a NodePort (30010 / 30020 / 30030 / 30040) serving an HTML page that shows which version answered, so a `curl` loop in a second terminal makes the behaviour visible:

```bash
# run in a second terminal during any of the labs
while true; do curl -s --connect-timeout 1 http://$(minikube ip):<nodePort> | grep -o 'VERSION: [^<]*' || echo "[OUTAGE]"; sleep 0.5; done
```

### 14.1 Rolling Update (default)

Kubernetes replaces old Pods with new ones **a few at a time**. The Service keeps serving throughout.

```
BEFORE                    DURING                     AFTER
[v1][v1][v1][v1]   ->   [v1][v1][v1][v2]   ->   [v2][v2][v2][v2]
 users served            users still served        users on v2
```

How one step works (with `maxSurge: 1`, `maxUnavailable: 0`):

1. Create 1 new v2 Pod (the "surge" Pod, so 5 Pods exist for a moment).
2. Wait until it passes its **readinessProbe**.
3. Only then terminate 1 old v1 Pod.
4. Repeat until every Pod is v2. At no point are fewer than 4 Pods Ready.

All of this is configured under `spec.strategy`: `type: RollingUpdate`, then `rollingUpdate.maxSurge` and `rollingUpdate.maxUnavailable`. Set the type explicitly even though it is the default; it documents intent.

| Setting | Meaning | Effect with 4 replicas |
|---------|---------|------------------------|
| `maxSurge: 1` | 1 extra Pod allowed temporarily | Up to 5 Pods during the rollout |
| `maxUnavailable: 0` | No Pod may be missing | Capacity never drops below 4 — the safe production setting |
| `maxSurge: 25%` / `maxUnavailable: 25%` | The **defaults** when you omit them | 1 extra, 1 missing; faster, brief 75% capacity |
| `maxSurge: 0, maxUnavailable: 1` | Never exceed `replicas` | For clusters with no spare capacity; rollout is slower |

Both accept an absolute number or a percentage; they cannot both be 0.

**Important points**

- The rollout advances **only after** the new Pod is Ready. **Without a readinessProbe** Kubernetes considers a Pod Ready the moment its container starts, so it will happily route traffic to a broken Pod. A readiness probe is what makes a rolling update safe.
- **v1 and v2 serve traffic at the same time** for the whole rollout. Your change must be backward compatible (API contract, DB schema, message formats). If it is not, use Blue-Green or Recreate.
- If the new image is broken (`ImagePullBackOff`, failing readiness) the rollout **stalls** and the old Pods keep serving — see [18.3](#183-rollout-failures--rollback). Set `progressDeadlineSeconds` (default 600) so a stuck rollout is reported instead of hanging silently.
- `minReadySeconds` (default 0) makes Kubernetes wait N seconds *after* a Pod becomes Ready before counting it as available — a cheap guard against Pods that pass readiness and then crash.
- Kubernetes keeps the last **10 ReplicaSets** for rollback (`revisionHistoryLimit: 10`).
- `kubectl rollout history` shows `CHANGE-CAUSE: <none>` unless you annotate: `kubectl annotate deploy/<name> kubernetes.io/change-cause="upgrade to v2"`.

```bash
kubectl apply -f 01-rolling-update/deployment-v1.yaml
kubectl apply -f 01-rolling-update/service.yaml
kubectl rollout status deployment/app-rolling               # "successfully rolled out"

kubectl apply -f 01-rolling-update/deployment-v2.yaml        # trigger the rollout
kubectl get pods -l app=app-rolling -w                       # watch v1 Terminating / v2 ContainerCreating interleave
kubectl rollout status  deployment/app-rolling
kubectl rollout history deployment/app-rolling               # REVISION 1, 2
kubectl rollout pause   deployment/app-rolling               # freeze mid-way (e.g. to inspect)
kubectl rollout resume  deployment/app-rolling
kubectl rollout undo    deployment/app-rolling               # back to v1 — itself a rolling update
```

**Use for:** any stateless microservice release or bug fix — the backbone of CD pipelines (GitHub Actions, ArgoCD, Tekton).

Lab files: `deployment-v1.yaml` (nginx 1.24, 4 replicas), `deployment-v2.yaml` … `v4.yaml` (nginx 1.25, `version` label bumped so you can roll several revisions), `service.yaml` (NodePort `30010`).

### 14.2 Recreate

The **all-or-nothing** strategy: terminate every old Pod, wait until they are gone, then create the new ones.

```
[v1] [v1] [v1]
      |  kubectl apply -f deployment-v2.yaml
      v
[Terminating] [Terminating] [Terminating]
      v
[ no Pods ]                 <--- DOWNTIME: connection refused / 502
      v
[ContainerCreating] x3
      v
[v2] [v2] [v2]
```

Configured with `spec.strategy.type: Recreate`. There are no sub-fields to tune.

**Why anyone chooses downtime**

1. **Breaking schema migrations** — v1 expects column `phone_number`, v2 splits it into `country_code` + `national_number`. Running both at once corrupts data. Stop v1, migrate, start v2.
2. **ReadWriteOnce volumes** — cloud disks (EBS, GCE PD) mount on **one node at a time**. A rolling update deadlocks: the old Pod holds the volume, the new Pod cannot attach it. Recreate releases it first.
3. **Single-instance legacy apps** — license servers, single-writer queues, anything that cannot run two copies.
4. **Tight dev/staging quotas** — no room for a surge Pod.

**Important points**

- `kubectl rollout undo` still works, but the rollback is *also* a Recreate — a second outage.
- Do it inside a **maintenance window**, and put a maintenance page in front if users can see it.
- The curl loop during the lab shows exactly what users would see:

```text
VERSION: v1
VERSION: v1
[OUTAGE] Connection failed
[OUTAGE] Connection failed
VERSION: v2 (UPGRADED)
```

```bash
kubectl apply -f 04-recreate/deployment-v1.yaml
kubectl apply -f 04-recreate/service.yaml                    # NodePort 30040
kubectl get pods -l app=app-recreate -w                      # terminal 1
kubectl apply -f 04-recreate/deployment-v2.yaml              # terminal 2 — all 3 go Terminating, then 3 new Pending
kubectl rollout undo deployment/app-recreate
```

### 14.3 Blue-Green

Run **two complete environments** side by side. **Blue** is the live version; **Green** is the new version, fully deployed and tested but receiving no traffic. Flip **one switch** — the Service's `selector` — and 100% of traffic moves at once.

```
PHASE 1  Users -> [Service: slot=blue]  -> [BLUE v1][BLUE v1][BLUE v1]    LIVE
                                           [GREEN v2][GREEN v2][GREEN v2]  idle, warming up / being tested

PHASE 2  Users -> [Service: slot=green] -> [GREEN v2][GREEN v2][GREEN v2]  LIVE
                                           [BLUE v1][BLUE v1][BLUE v1]     standby = instant rollback

PHASE 3  (rollback) apply service-blue.yaml again -> back on v1 in seconds
```

The two Deployments share a label (`app: myapp`) and differ by a **slot** label: Blue's Pods carry `slot: blue, version: v1`, Green's carry `slot: green, version: v2`. The two Service manifests are identical except for the `slot` value in `spec.selector`, so only one slot receives traffic at a time. Re-applying the file with `slot: green` **is** the switch.

**Why not just roll?**

- A rolling update has v1 and v2 serving **simultaneously**. Blue-Green never mixes: 100% v1 *or* 100% v2.
- Green can be **load-tested inside the real cluster** before it sees a single user.
- **Cutover and rollback both take seconds** — the time for kube-proxy to pick up the new endpoints.

**Important points**

- Costs **2x the resources** while both slots run. That is the price of instant switch and rollback.
- Keep Blue running for a while after the switch (the READMEs suggest ~24 h) as the rollback net, then delete it.
- Preferred for **database schema changes**: run the migration against Green, verify, then switch.
- Verify before and after the flip with `kubectl get endpoints myapp-service` — the IP list changes from the blue Pods to the green Pods.
- Instead of re-applying a file you can patch the live Service:
  `kubectl patch svc myapp-service -p '{"spec":{"selector":{"app":"myapp","slot":"green"}}}'`

```bash
kubectl apply -f 02-blue-green/deployment-blue.yaml
kubectl apply -f 02-blue-green/deployment-green.yaml
kubectl get pods -l app=myapp --show-labels                 # 3 slot=blue + 3 slot=green

kubectl apply -f 02-blue-green/service-blue.yaml            # v1 live on NodePort 30020
kubectl describe svc myapp-service | grep Selector          # app=myapp,slot=blue
kubectl get endpoints myapp-service

kubectl apply -f 02-blue-green/service-green.yaml           # THE SWITCH -> v2 live
kubectl describe svc myapp-service | grep Selector          # app=myapp,slot=green

kubectl apply -f 02-blue-green/service-blue.yaml            # rollback
kubectl delete deployment app-blue                          # decommission once green is trusted
```

**Use for:** major releases during off-peak hours, releases with DB migrations, regulated systems with a hard rollback SLA, services that cannot tolerate even one failed request.

### 14.4 Canary

Release v2 to a **small percentage of real users** first, watch error rate / latency / CPU, then widen it step by step. Named after the canary miners carried to detect gas before it hurt everyone.

```
                  [Service]  (selects app=myapp-canary — BOTH tracks)
                      |
        kube-proxy round-robins across ALL matching Pods
                      |
  [stable v1] x9  ...............................  [canary v2] x1
        90% of requests                                10% of requests
```

Two Deployments, one Service. The stable Deployment runs 9 replicas labelled `app: myapp-canary, track: stable, version: v1`; the canary runs 1 replica labelled `app: myapp-canary, track: canary, version: v2`. The Service selector is **only the shared label** `app: myapp-canary`, so it matches both sets. The `track` labels are for humans and for the two Deployments' own selectors, not for routing.

**Traffic split = Pod count ratio.** A plain Service has no weights; it round-robins across endpoints, so the percentage is only as fine as your replica counts:

| Stable | Canary | Total | Canary traffic |
|--------|--------|-------|----------------|
| 9 | 1 | 10 | 10% |
| 8 | 2 | 10 | 20% |
| 7 | 3 | 10 | 30% |
| 5 | 5 | 10 | 50% |
| 0 | 10 | 10 | 100% (promoted) |

**Important points**

- Kubernetes-native canary is **approximate**. For exact weights (5.3%), header/cookie-based routing, or automated promotion on metrics, use **Argo Rollouts**, **Flagger**, an Ingress controller with weight annotations (`nginx.ingress.kubernetes.io/canary-weight`), or a service mesh (Istio, Linkerd).
- Watch the canary for at least one full traffic cycle (15–30 min in production) before widening.
- Define the abort rule **before** going live: "error rate > 1% on canary Pods for 5 min -> scale canary to 0".
- Rollback is trivial: scale the canary to 0. 90% of users never saw the bug.
- Often paired with **feature flags**: only the 10% on canary Pods get the new flag.

```bash
kubectl apply -f 03-canary/deployment-stable.yaml            # 9 x v1
kubectl apply -f 03-canary/service.yaml                      # NodePort 30030
kubectl apply -f 03-canary/deployment-canary.yaml            # 1 x v2 -> ~10%
for i in $(seq 1 20); do curl -s http://$(minikube ip):30030 | grep -o "STABLE v1\|CANARY v2"; done

kubectl scale deployment app-canary --replicas=3             # widen to 30%
kubectl scale deployment app-stable --replicas=7
kubectl get endpoints myapp-canary-service                   # 10 IPs: 7 stable + 3 canary

kubectl scale deployment app-canary --replicas=9             # promote to 100%
kubectl scale deployment app-stable --replicas=0
kubectl delete deployment app-stable

kubectl scale deployment app-canary --replicas=0             # ...or abort
kubectl scale deployment app-stable --replicas=9
```

**Use for:** high-traffic services where you want real-user validation (Google, Netflix and Meta canary every push), ML model updates (serve the new model to 5%, compare accuracy), risky changes behind feature flags.

### 14.5 Comparison

| | RollingUpdate | Recreate | Blue-Green | Canary |
|--|---------------|----------|------------|--------|
| Downtime | None | **Yes** (brief) | None | None |
| v1 and v2 serve together | Yes, during rollout | Never | Never | Yes, deliberately, for a long time |
| Extra capacity needed | `maxSurge` (default +25%) | None | **+100%** | Small (the canary Pods) |
| Rollback | `rollout undo` (a second rolling update) | `rollout undo` (a second outage) | Flip selector back — seconds | Scale canary to 0 — seconds |
| Who sees a bad release | Everyone, gradually | Everyone | Everyone, instantly | Only the canary % |
| Native? | `spec.strategy` | `spec.strategy` | Pattern: 2 Deployments + Service selector | Pattern: 2 Deployments + replica ratio |
| Best for | Default for stateless services | Schema breaks, RWO volumes, dev clusters | Atomic cutover, DB migrations, hard rollback SLAs | Real-user validation before full rollout |

### 14.6 Choosing

```
Can v1 and v2 run at the same time (compatible API + schema)?
 |-- NO  -> can you afford a few seconds of downtime?
 |            |-- YES -> Recreate
 |            +-- NO  -> Blue-Green  (migrate Green first, then flip)
 +-- YES -> do you need to limit how many users see v2 first?
              |-- YES -> Canary   (then finish with a Rolling Update of stable)
              +-- NO  -> Rolling Update with maxUnavailable: 0 and a readinessProbe
```

In practice most teams run **Rolling Update** by default, reach for **Canary** on risky changes, and keep **Blue-Green** for migrations and regulated systems. **Recreate** is for the cases where nothing else is possible.

---

## 15. Pod Lifecycle & Health Probes

Hands-on lab for every case in this section: `Kubernetes_Objects/pod-lifecycle/` (run `kubectl get pods -w` in one terminal and apply the numbered files from another).

### 15.1 Pod Phases

`kubectl get pods` shows the Pod **phase** in the STATUS column (plus some more specific reasons — see 15.2):

| Phase | Meaning |
|-------|---------|
| `Pending` | Accepted by the API Server, but not running yet: waiting for scheduling, pulling an image, or an init container is still running |
| `Running` | Bound to a node, at least one container is running or starting |
| `Succeeded` | All containers exited with code 0 and will not be restarted (`restartPolicy: Never` / `OnFailure`) |
| `Failed` | All containers exited, at least one with non-zero, and will not be restarted |
| `Unknown` | The control plane lost contact with the node running the Pod |

```
                 scheduled          containers start
  Pending  ------------------>  Running  ---------->  Succeeded  (exit 0, no restart)
     |                              |
     | image pull fails             +---------------->  Failed     (exit != 0, no restart)
     v                              |
  ImagePullBackOff                  +--> crash --> restart --> crash ... CrashLoopBackOff
  (still phase Pending)                  (phase stays Running, RESTARTS climbs)
```

### 15.2 Container States and the STATUS column

Inside a Pod each container is `Waiting`, `Running`, or `Terminated`. `kubectl get pods` blends phase and the *reason* for waiting into one column, which is why you see values that are not phases:

| STATUS you see | What it really is |
|----------------|-------------------|
| `ContainerCreating` | Phase Pending; image being pulled or volumes mounting |
| `ErrImagePull` -> `ImagePullBackOff` | Phase Pending; image pull failed, kubelet retrying with growing back-off (up to 5 min) |
| `CrashLoopBackOff` | Phase Running; container keeps exiting, kubelet waits 10s, 20s, 40s ... 5 min between restarts |
| `Init:0/1` | Phase Pending; init containers still running |
| `Completed` | Phase Succeeded |
| `Error` | Phase Failed (or a container terminated with non-zero) |
| `Terminating` | Deletion requested, waiting for the grace period |
| `OOMKilled` | Container exceeded its memory **limit** and was killed |

`kubectl describe pod <pod>` shows the exact container state, `Last State`, `Exit Code`, and the **Events** that explain *why*.

### 15.3 Health Probes

The kubelet runs three kinds of probes against a container. Each can be an `httpGet`, a `tcpSocket`, or an `exec` command.

| Probe | Question it answers | On failure |
|-------|--------------------|------------|
| **startupProbe** | "Has the app finished starting?" | Kill and restart the container. While it runs, the other two probes are **disabled** — protects slow starters from being killed by an impatient liveness probe |
| **readinessProbe** | "Can this container serve traffic *right now*?" | Pod is marked **Not Ready** and **removed from Service endpoints**. Container is **not** restarted |
| **livenessProbe** | "Is the app still alive, or wedged?" | Kill and **restart** the container (obeying `restartPolicy`) |

Probes are declared per container as `startupProbe`, `readinessProbe` and `livenessProbe`. A typical combination:

| Probe | Mechanism | Timing | Effect |
|-------|-----------|--------|--------|
| `startupProbe` | `httpGet` on `/healthz` port 8080 | every 5 s, `failureThreshold: 30` | Up to 150 s allowed for a slow start; readiness and liveness stay off until it passes |
| `readinessProbe` | `httpGet` on `/ready` port 8080 | first check after 5 s, then every 5 s | Fails -> Pod leaves the Service endpoints, no restart |
| `livenessProbe` | `exec` a command such as testing that a health file exists | every 10 s, `failureThreshold: 3` | Three misses in a row -> container restarted |

The third mechanism, `tcpSocket`, just checks that a port accepts a connection; use it for non-HTTP services such as databases.

Common tuning fields:

| Field | Default | Meaning |
|-------|---------|---------|
| `initialDelaySeconds` | 0 | Wait before the first probe |
| `periodSeconds` | 10 | How often to probe |
| `timeoutSeconds` | 1 | How long one probe may take |
| `failureThreshold` | 3 | Consecutive failures before acting |
| `successThreshold` | 1 | Consecutive successes to be considered healthy again (only readiness may be >1) |

> **Readiness vs liveness in one sentence:** readiness takes the Pod *out of the load balancer*; liveness *restarts* it. A Pod can be `Running` but `0/1 READY` — that means the readiness probe is failing, and the Service will not send it traffic.

### 15.4 Init Containers

Run **before** the app containers, **in order**, each to completion. If one fails, the kubelet retries it (per `restartPolicy`) and the app containers never start.

They are declared under `spec.initContainers` with the same shape as a normal container. The classic example is a `busybox` init container whose command loops until it can open a TCP connection to `mysql:3306` and only then exits; the `nginx` app container in `spec.containers` starts after that. Other uses: running a schema migration, downloading configuration, fixing file permissions on a volume.

While init containers run, STATUS shows `Init:0/1`, then `PodInitializing`, then `Running`.

### 15.5 Graceful Termination

When a Pod is deleted (or replaced during a rollout):

```
1. Pod marked Terminating; removed from Service endpoints (no new traffic)
2. preStop hook runs (if defined)
3. SIGTERM sent to PID 1 of every container
4. Wait up to terminationGracePeriodSeconds (default 30s)
5. SIGKILL anything still running
```

Two knobs control this. `spec.terminationGracePeriodSeconds` (default 30) is the whole budget between SIGTERM and SIGKILL. A container's `lifecycle.preStop` hook (an `exec` command or an `httpGet`) runs *before* SIGTERM; a short sleep there is the usual trick to let the endpoint removal propagate to every node's kube-proxy so no new connections arrive while the app is shutting down.

> Your app must **handle SIGTERM** (close connections, flush, exit 0) to shut down cleanly. If it runs under a shell (`sh -c "..."`) the shell may swallow the signal — use `exec` or a `trap` (see `pod-lifecycle/12-termination.yaml`).

Force-delete a stuck Pod (last resort, skips the grace period):

```bash
kubectl delete pod <pod> --grace-period=0 --force
```

---

## 16. ConfigMap & Secret

Keep configuration out of the image so the same image runs in dev, staging, and prod.

| | ConfigMap | Secret |
|--|-----------|--------|
| For | Non-sensitive config: URLs, feature flags, config files | Passwords, API tokens, TLS certs |
| Stored as | Plain text | **base64-encoded** (not encrypted by default — enable encryption at rest / use RBAC) |
| Size limit | 1 MiB | 1 MiB |

A ConfigMap (`apiVersion: v1`, `kind: ConfigMap`) holds its key/value pairs under `data`, for example `APP_ENV: production` and `LOG_LEVEL: info`; a key can also hold a whole file's contents. A Secret (`kind: Secret`, `type: Opaque`) holds them under `data` (base64-encoded by you) or under `stringData` (plain text that Kubernetes base64-encodes for you). Other Secret types exist for specific shapes: `kubernetes.io/tls` for certificates, `kubernetes.io/dockerconfigjson` for registry credentials (`imagePullSecrets`).

Two ways to consume them in a Pod, both declared in the Pod template:

| How | Where in the manifest | What the app sees |
|-----|-----------------------|-------------------|
| One key as an env var | `env[].valueFrom.configMapKeyRef` (name + key) or `secretKeyRef` | `APP_ENV=production` |
| Every key as env vars | `envFrom[].configMapRef` or `envFrom[].secretRef` | One variable per key |
| As files | A `volumes[]` entry of type `configMap` or `secret`, mounted with `volumeMounts[].mountPath` (for example `/etc/config`) | One file per key, the value is the file content |

```bash
kubectl create configmap app-config --from-literal=APP_ENV=prod --from-file=app.properties
kubectl create secret generic db-secret --from-literal=MYSQL_ROOT_PASSWORD=password
kubectl get secret db-secret -o jsonpath='{.data.MYSQL_ROOT_PASSWORD}' | base64 -d
```

> Env vars are read once at container start — changing a ConfigMap does **not** update a running Pod's environment. Mounted files *do* update (with a delay), but the app has to re-read them. Simplest fix: `kubectl rollout restart deploy/<name>`.

---

## 17. Cluster DNS: CoreDNS & FQDN

### 17.1 What CoreDNS Is

Pods get new IPs every time they are recreated, so nothing inside the cluster should hard-code an IP. Instead, Pods talk to **names**, and **CoreDNS** turns those names into IPs.

CoreDNS is the cluster's DNS server. It runs as a normal Deployment in `kube-system`, is exposed by a ClusterIP Service called `kube-dns` (the name is historical — it replaced the older kube-dns), and **watches the API Server** for Services and Endpoints so its records are always current.

```bash
kubectl get deploy,svc -n kube-system -l k8s-app=kube-dns
# deployment.apps/coredns    2/2
# service/kube-dns   ClusterIP   10.96.0.10   ... 53/UDP,53/TCP,9153/TCP
```

Every Pod's `/etc/resolv.conf` is written by the kubelet and contains three lines: `nameserver 10.96.0.10` (the kube-dns ClusterIP), `search default.svc.cluster.local svc.cluster.local cluster.local` (the suffixes tried for short names, with the Pod's own namespace first), and `options ndots:5` (explained in [17.2](#172-fqdn--fully-qualified-domain-name)).

```
Pod: "connect to myapp-service"
   |  DNS query -> 10.96.0.10 (kube-dns Service)
   v
CoreDNS Pod  ---watches---> API Server (Services, EndpointSlices)
   |  answer: myapp-service.default.svc.cluster.local = 10.96.45.12 (the Service's ClusterIP)
   v
Pod connects to 10.96.45.12:80
   |  kube-proxy iptables rule
   v
one backing Pod
```

> DNS returns the **Service's ClusterIP**, not a Pod IP. Load balancing is done afterwards by kube-proxy. The exception is a **headless** Service (`clusterIP: None`), where DNS returns the Pod IPs directly — that is how StatefulSet Pods are found individually.

### 17.2 FQDN — Fully Qualified Domain Name

An **FQDN** is the complete, unambiguous name of a host, all the way to the root. Inside Kubernetes every Service gets one:

```
<service-name>.<namespace>.svc.<cluster-domain>

myapp-service . default . svc . cluster.local
     |            |       |         |
  Service      Namespace  "this   cluster domain
   name                   is a    (default cluster.local,
                          Service" set in kubelet / CoreDNS)
```

| Name you can use | Resolves when | Why |
|------------------|---------------|-----|
| `myapp-service` | Caller is in the **same** namespace | The first `search` suffix (`default.svc.cluster.local`) is appended |
| `myapp-service.dev` | Caller is in **any** namespace | The second suffix (`svc.cluster.local`) completes it |
| `myapp-service.dev.svc` | Any namespace | Third suffix (`cluster.local`) completes it |
| `myapp-service.dev.svc.cluster.local` | Any namespace — the full FQDN | Nothing appended; most explicit, use this in config files |
| `myapp-service.dev.svc.cluster.local.` | Same, with a trailing dot | Skips the search list entirely; fastest lookup |

Records CoreDNS serves:

| Record | Format | Example |
|--------|--------|---------|
| Service (A/AAAA -> ClusterIP) | `<svc>.<ns>.svc.cluster.local` | `myapp-service.default.svc.cluster.local` |
| Headless Service (A -> each Pod IP) | same name, multiple answers | `mysql.default.svc.cluster.local` -> 3 Pod IPs |
| StatefulSet Pod | `<pod>.<headless-svc>.<ns>.svc.cluster.local` | `mysql-0.mysql.default.svc.cluster.local` |
| Pod by IP (rarely used) | `<ip-with-dashes>.<ns>.pod.cluster.local` | `10-244-0-5.default.pod.cluster.local` |
| Named port (SRV) | `_<port>._<proto>.<svc>.<ns>.svc.cluster.local` | `_http._tcp.myapp-service.default.svc.cluster.local` |
| API Server | `kubernetes.default.svc.cluster.local` | always present |

**How `search` and `ndots:5` work.** A name with fewer than 5 dots is *not* treated as fully qualified: the resolver tries it with each `search` suffix first, and only then as-is. So `myapp-service` becomes `myapp-service.default.svc.cluster.local` on the first try, which is why short names work. The downside: an **external** name like `api.github.com` (2 dots) also gets tried as `api.github.com.default.svc.cluster.local`, `api.github.com.svc.cluster.local`, `api.github.com.cluster.local` before the real lookup — 3 wasted queries. Fixes: use a trailing dot (`api.github.com.`), or lower `ndots` via `dnsConfig`.

### 17.3 Pod `dnsPolicy`

| `dnsPolicy` | Behaviour | Use |
|-------------|-----------|-----|
| `ClusterFirst` (default) | Cluster names via CoreDNS; everything else forwarded to the node's upstream DNS | Almost always |
| `ClusterFirstWithHostNet` | Same, for Pods with `hostNetwork: true` (which would otherwise get `Default`) | Node agents that still need cluster DNS |
| `Default` | Inherit the **node's** `/etc/resolv.conf`; cluster names do **not** resolve | Pods that only talk to the outside world |
| `None` | Ignore everything; you supply `dnsConfig` | Custom resolvers, tuning `ndots` |

With `dnsPolicy: None` you supply a `dnsConfig` block on the Pod: `nameservers` (a list of resolver IPs), `searches` (the suffix list) and `options` (for example `ndots` set to `2`). `dnsConfig` can also be combined with `ClusterFirst` to *add* options without replacing the defaults.

### 17.4 Configuration — the Corefile

CoreDNS is configured by a ConfigMap called `coredns` in `kube-system`. Its `Corefile` is a chain of plugins applied to every query on port 53:

| Plugin | What it does |
|--------|--------------|
| `errors` / `health` / `ready` | Logging and the health endpoints the Deployment's probes hit |
| `kubernetes cluster.local in-addr.arpa ip6.arpa` | Serves the cluster records for the `cluster.local` domain (and reverse lookups) straight from the API Server watch |
| `forward . /etc/resolv.conf` | Anything that is **not** a cluster name goes to the node's upstream DNS |
| `cache 30` | Answers are cached for 30 s |
| `loop` | Detects forwarding loops |
| `reload` | Picks up ConfigMap edits without a restart |

Editing this ConfigMap is how you add custom upstreams, stub domains for a corporate DNS zone, or rewrite rules.

```bash
kubectl get cm coredns -n kube-system -o yaml
```

### 17.5 Debugging DNS

```bash
# 1. Is CoreDNS up?
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl logs   -n kube-system -l k8s-app=kube-dns --tail=50

# 2. Resolve from inside the cluster
kubectl run dnstest --rm -it --image=busybox:1.36 -- sh
  cat /etc/resolv.conf                                 # nameserver should be the kube-dns ClusterIP
  nslookup myapp-service                               # short name, same namespace
  nslookup myapp-service.dev.svc.cluster.local         # FQDN, any namespace
  nslookup kubernetes.default                          # sanity check — always exists
  wget -qO- http://myapp-service.dev:80

# 3. The Service itself
kubectl get svc myapp-service -n dev                   # does it exist, in THAT namespace?
kubectl get endpoints myapp-service -n dev             # resolves but no connection? -> empty endpoints
```

| Symptom | Likely cause |
|---------|-------------|
| `nslookup: can't resolve 'myapp-service'` | Service is in a different namespace (add `.<ns>`), typo, or Service not created yet |
| Nothing resolves, not even `kubernetes.default` | CoreDNS Pods down / CrashLoopBackOff, or Pod `dnsPolicy: Default` |
| Resolves, but connection refused / timeout | DNS is fine. Service has no endpoints (selector mismatch), wrong `targetPort`, or readiness failing — see [18.4](#184-service-not-reachable) |
| Slow external lookups | `ndots:5` search-list churn — use a trailing dot or lower `ndots` |

> Rule of thumb: **DNS answers "what IP is this name"; endpoints answer "is anyone behind that IP"**. Check them in that order.

---

## 18. Troubleshooting

### 18.1 The Debugging Order

Always in this order — each step tells you where to look next:

```
1. kubectl get pods -o wide            -> which Pod, what STATUS, how many RESTARTS, which node
2. kubectl describe pod <pod>          -> Events at the bottom: scheduling, image pull, probe failures
3. kubectl logs <pod> [-c <container>] -> what the app itself said
   kubectl logs <pod> --previous       -> logs of the crashed container before the restart
4. kubectl exec -it <pod> -- sh        -> poke around inside (env, files, curl localhost)
5. kubectl get events --sort-by=.metadata.creationTimestamp   -> cluster-wide timeline
```

### 18.2 Common Pod Errors

| Status | Likely cause | Where to look / fix |
|--------|-------------|---------------------|
| `ErrImagePull` / `ImagePullBackOff` | Wrong image name or tag; private registry without credentials; image only exists on your host Docker (Minikube has its own store) | `describe pod` Events. Fix the tag, add `imagePullSecrets`, or `minikube image load` |
| `CrashLoopBackOff` | App starts then exits: bad command, missing env var, config error, port in use, or a one-shot task without `restartPolicy: Never` | `kubectl logs <pod> --previous` |
| `Pending` | No node fits: `requests` too large, taint without toleration, `nodeSelector` matches nothing, PVC not bound | `describe pod` -> `FailedScheduling` event says exactly why |
| `ContainerCreating` (stuck) | Volume / ConfigMap / Secret referenced but missing; CNI not ready | `describe pod` Events (`FailedMount`) |
| `OOMKilled` | Memory **limit** too low, or a leak | Raise `resources.limits.memory` or fix the app |
| `Running` but `0/1 READY` | Readiness probe failing | `describe pod` -> `Unhealthy` events; check the probe path/port |
| `Completed` | Container exited 0 — normal for a one-shot Pod | Nothing to fix |
| `Error` | Container exited non-zero with `restartPolicy: Never` | `kubectl logs <pod>` |
| `Terminating` (stuck) | Finalizers, or app ignoring SIGTERM past the grace period | Wait, or `--grace-period=0 --force` |
| `CreateContainerConfigError` | Referenced ConfigMap/Secret key does not exist | `describe pod` Events |

### 18.3 Rollout Failures & Rollback

Lab: `Kubernetes_Objects/troubleshooting/broken-image.yaml`.

Scenario: a Deployment with `maxSurge: 1, maxUnavailable: 0` is updated to an image tag that does not exist.

```
1. New ReplicaSet created, 1 surge Pod scheduled
2. That Pod -> ErrImagePull -> ImagePullBackOff, never Ready
3. Rollout STALLS: Kubernetes will not kill an old Pod until a new one is Ready
4. Old Pods (3/3) keep serving traffic the whole time   <- this is the point of the strategy
```

Diagnose and recover:

```bash
kubectl rollout status deploy/<name>              # "Waiting for deployment ... 1 out of 3 new replicas have been updated"
kubectl get rs                                    # new RS shows DESIRED 1 / READY 0
kubectl get pods                                  # the one new Pod is ImagePullBackOff
kubectl describe pod <new-pod>                    # Events: Failed to pull image ... not found

kubectl rollout history deploy/<name>
kubectl rollout undo deploy/<name>                # back to the last working revision
kubectl rollout status deploy/<name>              # "successfully rolled out"
```

Set `progressDeadlineSeconds` (default 600) so a stuck rollout is flagged `ProgressDeadlineExceeded` in `kubectl describe deploy` instead of hanging silently.

### 18.4 Service Not Reachable

How a Service is *supposed* to work (selector -> endpoints -> kube-proxy) is in [13.2](#132-how-a-service-works); this is the checklist for when it does not.

```bash
kubectl get endpoints <svc>          # EMPTY  -> Service selector matches no Pod labels
                                     # has IPs -> Service is fine, problem is the Pod/port
kubectl describe svc <svc>           # compare Selector with:
kubectl get pods --show-labels
kubectl get pods -l <key>=<value>    # do any Pods actually carry the label?
kubectl port-forward pod/<pod> 8080:<containerPort>   # bypass the Service; is the app itself up?
kubectl run tmp --rm -it --image=busybox:1.36 -- sh   # from inside the cluster:
  wget -qO- http://<svc>:<port>
```

Checklist: selector ≠ labels, `targetPort` ≠ the port the app listens on, readiness probe failing (Pod not in endpoints), wrong namespace (name does not resolve — see [18.6](#186-name-does-not-resolve)).

### 18.5 Deleting Things That Come Back

Deleting a Pod owned by a ReplicaSet/Deployment does nothing lasting — the controller recreates it immediately. Delete the **owner**:

```bash
kubectl get pod <pod> -o jsonpath='{.metadata.ownerReferences[0].kind}/{.metadata.ownerReferences[0].name}'
kubectl delete deploy <name>         # removes the Deployment, its ReplicaSets, and their Pods
```

### 18.6 Name Does Not Resolve

```bash
kubectl run dnstest --rm -it --image=busybox:1.36 -- nslookup <svc>.<ns>.svc.cluster.local
kubectl get pods -n kube-system -l k8s-app=kube-dns          # CoreDNS healthy?
kubectl get svc <svc> -n <ns>                                # right namespace?
```

Short names only work **inside the same namespace**; from anywhere else use `<svc>.<ns>`. Full DNS reference and symptom table: [17.5](#175-debugging-dns).

---

## 19. kubectl Command Reference

`kubectl` is the command-line interface to the cluster. Every command is an HTTPS request to the **kube-apiserver**, which is why the same commands work on Minikube, kind, EKS, GKE, and AKS.

General shape:

```
kubectl <verb> <resource> [<name>] [flags]
        get     pods       nginx    -n dev -o wide
```

### 19.1 Cluster Info & Context

Your **kubeconfig** (`~/.kube/config`) holds one or more clusters, users, and **contexts** (cluster + user + default namespace). `minikube start` writes one for you.

| Command | Purpose |
|---------|---------|
| `kubectl version` | Client and server versions |
| `kubectl cluster-info` | API Server URL, CoreDNS |
| `kubectl get nodes` / `-o wide` | Nodes, their status, roles, versions, IPs |
| `kubectl config view` | Show the merged kubeconfig |
| `kubectl config get-contexts` | List contexts; `*` marks the current one |
| `kubectl config current-context` | Which cluster you are pointed at |
| `kubectl config use-context <ctx>` | Switch clusters |
| `kubectl config set-context --current --namespace=dev` | Change the default namespace for this context |
| `kubectl api-resources` | Every resource kind the server knows, with short names |

```bash
kubectl version
kubectl config use-context minikube
kubectl get nodes -o wide
```

### 19.2 Get (list resources)

| Command | Purpose |
|---------|---------|
| `kubectl get pods` | Pods in the current namespace |
| `kubectl get pods -o wide` | + node, Pod IP, nominated node |
| `kubectl get pods -A` | Every namespace (`--all-namespaces`) |
| `kubectl get pods -n <ns>` | A specific namespace |
| `kubectl get pods -w` | Watch for changes live (Ctrl+C to stop) |
| `kubectl get pods -l app=myapp` | Filter by label |
| `kubectl get pods --show-labels` | Add a LABELS column |
| `kubectl get svc` / `deploy` / `rs` / `ds` / `sts` | Services, Deployments, ReplicaSets, DaemonSets, StatefulSets |
| `kubectl get deploy,rs,pod` | Several kinds at once |
| `kubectl get all` | Pods, Services, Deployments, ReplicaSets, StatefulSets (not ConfigMaps/Secrets/Ingress) |
| `kubectl get endpoints <svc>` | Which Pod IPs a Service is actually sending to |
| `kubectl get events --sort-by=.metadata.creationTimestamp` | Cluster event timeline |
| `kubectl get ns` | Namespaces |
| `kubectl get <kind> <name> -o yaml` | Full live object, including `status` |
| `kubectl get <kind> <name> -o json` | Same, as JSON |
| `kubectl get pods -o jsonpath='{.items[*].metadata.name}'` | Extract specific fields |
| `kubectl get pods -o name` | Just `pod/<name>` lines (handy for scripting) |

```bash
kubectl get pods -n dev -o wide
kubectl get svc -o wide
kubectl get pods -w
```

### 19.3 Describe (detailed info + Events)

`describe` is the first stop when something is wrong — the **Events** block at the bottom tells you what the scheduler, kubelet, and controllers did and why.

| Command | Purpose |
|---------|---------|
| `kubectl describe pod <pod>` | Containers, images, state, probes, volumes, Events |
| `kubectl describe deploy <name>` | Strategy, replicas, conditions, rollout Events |
| `kubectl describe rs <name>` | Owner Deployment, replica counts |
| `kubectl describe svc <name>` | Selector, type, ports, **Endpoints** |
| `kubectl describe node <node>` | Capacity, allocated resources, taints, conditions, Pods on it |

```bash
kubectl describe pod myapp-7b8d99c9
kubectl describe node minikube
```

### 19.4 Create / Apply / Delete

| Command | Purpose |
|---------|---------|
| `kubectl apply -f <file.yml>` | Create **or update** from a manifest (declarative — preferred) |
| `kubectl apply -f <folder>/` | Apply every manifest in a folder |
| `kubectl apply -f <file> --dry-run=server` | Validate against the API without changing anything |
| `kubectl diff -f <file.yml>` | Show what `apply` would change |
| `kubectl create -f <file.yml>` | Create only; **fails if it already exists** (imperative) |
| `kubectl create deploy <name> --image=<img>` | Imperative Deployment without a file |
| `kubectl run <name> --image=<img>` | Imperative bare Pod (for quick tests) |
| `kubectl expose deploy <name> --port=80 --type=NodePort` | Create a Service for a Deployment |
| `kubectl delete -f <file.yml>` | Delete exactly what that file created |
| `kubectl delete pod <name>` | Delete one object (`deploy`, `rs`, `svc`, ... likewise) |
| `kubectl delete pod -l app=myapp` | Delete by label |
| `kubectl delete all --all` | Delete every Pod/Service/Deployment/RS in the namespace — **careful** |
| `kubectl delete pod <name> --grace-period=0 --force` | Force-delete a stuck Pod |

```bash
kubectl apply -f deployment.yml
kubectl apply -f ./k8s-core-objects/
kubectl delete svc frontend
```

See [11.2](#112-create-vs-apply) for the full create-vs-apply comparison.

### 19.5 Logs & Exec (troubleshooting inside a Pod)

| Command | Purpose |
|---------|---------|
| `kubectl logs <pod>` | Container stdout/stderr |
| `kubectl logs -f <pod>` | Follow / tail |
| `kubectl logs <pod> -c <container>` | A specific container in a multi-container Pod |
| `kubectl logs <pod> --previous` | Logs from the **crashed** instance before the last restart (CrashLoopBackOff!) |
| `kubectl logs <pod> --tail=100 --since=10m` | Limit output |
| `kubectl logs -l app=myapp --all-containers` | Logs from every Pod with that label |
| `kubectl logs deploy/<name>` | Logs from one Pod of the Deployment |
| `kubectl exec <pod> -- <cmd>` | Run one command inside the container |
| `kubectl exec -it <pod> -- sh` | Interactive shell (`bash` if the image has it; alpine/busybox only have `sh`) |
| `kubectl exec -it <pod> -c <container> -- sh` | Shell into a specific container |
| `kubectl cp <pod>:/path/file ./file` | Copy files out of (or into) a container |
| `kubectl top pod` / `kubectl top node` | Live CPU/memory (needs metrics-server: `minikube addons enable metrics-server`) |

```bash
kubectl logs myapp-pod --previous
kubectl exec -it myapp-pod -- sh
kubectl exec myapp-pod -- env
```

### 19.6 Port Forwarding

Tunnel a local port to a Pod or Service without exposing anything — the fastest way to hit an app from your laptop.

| Command | Purpose |
|---------|---------|
| `kubectl port-forward pod/<pod> <local>:<containerPort>` | localhost:`<local>` -> Pod |
| `kubectl port-forward svc/<svc> <local>:<port>` | localhost:`<local>` -> Service (picks one backing Pod) |
| `kubectl port-forward deploy/<name> <local>:<containerPort>` | -> one Pod of the Deployment |

```bash
kubectl port-forward pod/myapp-7b8d 8080:80      # then open http://localhost:8080
kubectl port-forward svc/myapp-service 8080:80
```

Runs in the foreground; Ctrl+C stops it.

### 19.7 Scaling & Rollouts

| Command | Purpose |
|---------|---------|
| `kubectl scale deploy <name> --replicas=N` | Change the desired Pod count |
| `kubectl scale rs <name> --replicas=N` | Same for a bare ReplicaSet (a Deployment would overwrite this on its own RS) |
| `kubectl scale sts <name> --replicas=N` | StatefulSet |
| `kubectl autoscale deploy <name> --min=2 --max=10 --cpu-percent=80` | HorizontalPodAutoscaler (needs metrics-server) |
| `kubectl set image deploy/<name> <container>=<image:tag>` | Change the image -> triggers a rolling update |
| `kubectl rollout status deploy/<name>` | Wait for / watch a rollout |
| `kubectl rollout history deploy/<name>` | Revision list |
| `kubectl rollout history deploy/<name> --revision=2` | What a revision contained |
| `kubectl rollout undo deploy/<name>` | Back to the previous revision |
| `kubectl rollout undo deploy/<name> --to-revision=N` | Back to a specific one |
| `kubectl rollout pause` / `resume deploy/<name>` | Freeze / continue a rollout |
| `kubectl rollout restart deploy/<name>` | Rolling restart with the same spec (picks up new ConfigMap/Secret values) |

```bash
kubectl scale deployment myapp --replicas=5
kubectl set image deploy/myapp backend=myapp:v2
kubectl rollout status deploy/myapp
kubectl rollout undo deploy myapp
```

> There is no `kubectl scale pod`. A Pod is a single instance; only controllers (ReplicaSet, Deployment, StatefulSet) have `replicas`.

### 19.8 YAML Generation, Dry Run & Explain

Never write manifests from memory — generate a skeleton and edit it.

| Command | Purpose |
|---------|---------|
| `kubectl create deploy <name> --image=<img> --dry-run=client -o yaml` | Print Deployment YAML, create nothing |
| `kubectl run <name> --image=<img> --dry-run=client -o yaml` | Pod YAML |
| `kubectl create svc nodeport <name> --tcp=80:8080 --dry-run=client -o yaml` | Service YAML |
| `kubectl expose deploy <name> --port=80 --dry-run=client -o yaml` | Service YAML from a Deployment's labels |
| `kubectl create cm <name> --from-literal=k=v --dry-run=client -o yaml` | ConfigMap YAML |
| `kubectl apply -f <file> --dry-run=server` | Validate a file against the real API Server |
| `kubectl explain <resource>` | Documentation for a kind |
| `kubectl explain <resource>.<field>.<field>` | Drill into any field |
| `kubectl explain <resource> --recursive` | Every field at once |

```bash
kubectl create deployment nginx --image=nginx --dry-run=client -o yaml > deployment.yml
kubectl explain pod.spec.containers
kubectl explain deployment.spec.strategy.rollingUpdate
```

`--dry-run=client` never talks to the cluster; `--dry-run=server` sends the request and lets the API Server validate it, but does not persist it.

### 19.9 Namespaces

| Command | Purpose |
|---------|---------|
| `kubectl get ns` | List namespaces |
| `kubectl create ns <name>` | Create one |
| `kubectl delete ns <name>` | Delete it **and everything in it** |
| `kubectl get <kind> -n <ns>` | Work in a specific namespace |
| `kubectl get <kind> -A` | Across all namespaces |
| `kubectl config set-context --current --namespace=<ns>` | Change the default for every following command |

```bash
kubectl get pods -n prod
kubectl config set-context --current --namespace=dev
```

### 19.10 Edit, Patch, Label, Annotate (change live objects)

| Command | Purpose |
|---------|---------|
| `kubectl edit <kind> <name>` | Open the live object in `$EDITOR`; saved changes are applied immediately |
| `kubectl patch <kind> <name> -p '<json>'` | Apply a partial change without opening an editor |
| `kubectl label <kind> <name> key=value` | Add / change a label (`key-` removes it) |
| `kubectl annotate <kind> <name> key=value` | Add an annotation (e.g. `kubernetes.io/change-cause`) |
| `kubectl replace -f <file.yml>` | Replace the whole object (fails if it does not exist) |

```bash
kubectl edit deployment myapp
kubectl patch deployment myapp -p '{"spec":{"replicas":4}}'
kubectl label pod myapp-7b8d env=prod
```

> `edit`/`patch` change the **live** object only. Your YAML file on disk is now out of date, and the next `kubectl apply -f` will revert the change. For anything you keep in Git, edit the file and `apply`.

### 19.11 Short Names & Output Formats

Short names accepted anywhere a resource kind is expected:

| Short | Full | Short | Full |
|-------|------|-------|------|
| `po` | pods | `deploy` | deployments |
| `svc` | services | `rs` | replicasets |
| `ns` | namespaces | `ds` | daemonsets |
| `no` | nodes | `sts` | statefulsets |
| `cm` | configmaps | `ep` | endpoints |
| `pv` / `pvc` | persistentvolumes / persistentvolumeclaims | `ing` | ingresses |
| `sa` | serviceaccounts | `netpol` | networkpolicies |

`kubectl api-resources` shows the complete list.

Output flags (`-o`):

| Flag | Gives you |
|------|-----------|
| `-o wide` | Extra columns (node, IP, images) |
| `-o yaml` / `-o json` | The full object |
| `-o name` | `kind/name` only |
| `-o jsonpath='{...}'` | A specific field |
| `-o custom-columns=NAME:.metadata.name,NODE:.spec.nodeName` | Your own table |

```bash
kubectl get po
kubectl get svc -o wide
kubectl get po -o custom-columns=NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName
```

### 19.12 Quality-of-Life

```bash
alias k=kubectl                                  # bash / zsh
Set-Alias -Name k -Value kubectl                 # PowerShell

source <(kubectl completion bash)                # tab completion (bash)
kubectl completion powershell | Out-String | Invoke-Expression   # PowerShell

kubectl get pods -w                              # watch live while applying files elsewhere
watch kubectl get pods                           # Linux/Mac alternative
```



---

## 20. ConfigMap, Secret & Ingress (Session 12)

### 20.1 The Problem These Solve

If you hardcode config (`LOG_LEVEL`, `DB_HOST`, passwords) inside your code or Docker image, you must **rebuild the image every time a value changes**. Dev, staging and prod would each need a different image.

12-Factor rule: **the code/image stays the same in every environment, only the configuration changes.**

Kubernetes gives two objects for this:

| Object | Stores | Example |
|--------|--------|---------|
| **ConfigMap** | Non-sensitive, environment-specific data | log level, port, API URL, feature flags |
| **Secret** | Sensitive, environment-specific data | DB password, API keys, TLS cert/key |

> `kubectl get all` does **not** show ConfigMaps or Secrets. Check them separately:
> `kubectl get configmaps` (or `kubectl get cm`) and `kubectl get secret`.

---

### 20.2 ConfigMap

**What it is:** plain-text key/value pairs stored outside the image. The app reads them at runtime as env vars or as files.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: yatri-app-config
data:
  LOG_LEVEL: "INFO"
  PORT: "5000"
  DATABASE_HOST: "postgres-service"
```

**How a Pod uses it:**

| Method | YAML | Result inside the container |
|--------|------|-----------------------------|
| All keys as env vars | `envFrom: - configMapRef: {name: yatri-app-config}` | `LOG_LEVEL=INFO`, `PORT=5000`, ... |
| One key as env var | `env: - name: LOG_LEVEL valueFrom: configMapKeyRef: {name: ..., key: LOG_LEVEL}` | just `LOG_LEVEL=INFO` |
| As files | `volumes: - configMap: {name: ...}` + `volumeMounts: mountPath: /etc/config` | one file per key, value is the file content |

**Commands:**

```bash
kubectl apply -f app-config.yaml
kubectl create configmap app-config --from-literal=LOG_LEVEL=INFO   # imperative way
kubectl get configmaps                 # or: kubectl get cm
kubectl describe configmap yatri-app-config
kubectl delete configmap yatri-app-config
```

**Remember:**
- Only for **non-sensitive** data. Never put passwords or certificates here.
- Size limit is **1 MiB**.
- Changing a ConfigMap does **not** restart running Pods. Env vars are read only at container start. Run `kubectl rollout restart deploy/<name>` to pick up new values.

---

### 20.3 Secret

**What it is:** same idea as ConfigMap, but for sensitive data. Values are stored **base64-encoded**.

```bash
echo -n "secretpassword" | base64            # encode  -> c2VjcmV0cGFzc3dvcmQ=
echo -n "c2VjcmV0cGFzc3dvcmQ=" | base64 -d   # decode  -> secretpassword
```

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: yatri-db-secret
type: Opaque
data:                                  # values must be base64
  POSTGRES_USER: eWF0cmlfYWRtaW4=
  POSTGRES_PASSWORD: c2VjcmV0cGFzc3dvcmQ=
```

> You can also use `stringData:` with plain-text values and Kubernetes base64-encodes them for you.

**Secret types:**

| Type | Used for |
|------|----------|
| `Opaque` | Generic key/value (default) |
| `kubernetes.io/tls` | TLS certificate + private key (`tls.crt`, `tls.key`) |
| `kubernetes.io/dockerconfigjson` | Private registry login (`imagePullSecrets`) |

**How a Pod uses it:** exactly like a ConfigMap, just swap the ref name.

- `envFrom: - secretRef: {name: yatri-db-secret}` -> all keys as env vars
- `env: valueFrom: secretKeyRef: {name: ..., key: POSTGRES_PASSWORD}` -> one key
- `volumes: - secret: {secretName: ...}` -> mounted as files (used for TLS keys)

**Commands:**

```bash
kubectl apply -f db-secret.yaml
kubectl create secret generic db-secret --from-literal=POSTGRES_PASSWORD=secretpassword
kubectl create secret tls campus-tls-cert --cert=tls.crt --key=tls.key
kubectl get secret
kubectl describe secret yatri-db-secret        # values are hidden, shows only "[N bytes]"
kubectl get secret yatri-db-secret -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d   # decode to check
kubectl delete secret yatri-db-secret
```

**Remember:**
- **Base64 is encoding, NOT encryption.** Anyone with `kubectl get secret` access can decode it. Real protection comes from **RBAC** and **encryption at rest** in etcd.
- For production use an external manager: AWS Secrets Manager, HashiCorp Vault, GCP Secret Manager (via External Secrets Operator).
- **Always use `echo -n`** when encoding. Without `-n` a trailing newline (`\n`) gets encoded too, so the app sends `password\n` and login fails with `password authentication failed`. Hint: correct base64 for short strings usually ends in `==`, the buggy one ends in `Ao=` / `o=`.

**ConfigMap vs Secret:**

| | ConfigMap | Secret |
|--|-----------|--------|
| Data | Non-sensitive | Sensitive |
| Stored as | Plain text | Base64 |
| Check with | `kubectl get cm` | `kubectl get secret` |
| `describe` shows values? | Yes | No (masked) |
| Size limit | 1 MiB | 1 MiB |

---

### 20.4 Ingress

**The problem:** without Ingress every service that needs to be public needs its own `LoadBalancer` Service. On AWS that is one load balancer (about $25/month) **per service**, ugly URLs like `http://3.15.22.100:30080`, no HTTPS, and no central routing.

**The solution:** one **Ingress Controller** (e.g. NGINX) sits behind a **single** LoadBalancer. You write **Ingress rules** in YAML that say which host/path goes to which ClusterIP Service.

```text
Internet --> 1 LoadBalancer --> NGINX Ingress Controller (Layer 7 reverse proxy)
                                          |
                     +--------------------+--------------------+
                     |                                         |
              yatri.local/                              yatri.local/api/*
                     |                                         |
          Frontend Service (ClusterIP)              Backend Service (ClusterIP)
```

**Two parts, both required:**

| Part | What it is |
|------|------------|
| **Ingress Controller** | The actual pod (reverse proxy) that receives traffic. Must be installed once per cluster. On Minikube: `minikube addons enable ingress`. On EKS: install `ingress-nginx` via Helm. |
| **Ingress resource** | Just the routing rules in YAML. Does **nothing** on its own without a controller. |

**Ingress vs Ingress Controller:**

| | Ingress | Ingress Controller |
|--|---------|--------------------|
| What is it | A Kubernetes **object** (YAML, `kind: Ingress`) | A **running Pod** (NGINX, Traefik, HAProxy, AWS ALB...) |
| Job | Describes the rules: this host/path goes to that Service | Reads those rules and actually forwards the traffic |
| Comes with Kubernetes? | Yes, the API is built in | No, you install it yourself (`minikube addons enable ingress`, Helm on EKS) |
| How many | One per app / team, as many as you need | Usually one per cluster |
| Exposed to internet? | No, it is just config | Yes, via a single LoadBalancer / NodePort Service |
| Linked by | `spec.ingressClassName: nginx` | The `IngressClass` name it watches |
| Check with | `kubectl get ingress` | `kubectl get pods -n ingress-nginx` |

Simple way to remember: **Ingress = the rulebook, Ingress Controller = the traffic cop who reads it.** If you apply an Ingress but no controller is installed, `kubectl get ingress` shows an empty `ADDRESS` and nothing is reachable.

**Routing types:**

- **Path-based:** `/` -> frontend, `/api` -> backend (same host)
- **Host-based:** `portal.campus.local` -> portal, `api.campus.local` -> api (same IP)
- **TLS termination:** HTTPS ends at the Ingress. Backends talk plain HTTP inside the cluster.

**Example - path-based routing:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: yatri-ingress
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/use-regex: "true"
spec:
  ingressClassName: nginx            # which controller handles this
  rules:
    - host: yatri.local
      http:
        paths:
          - path: /api(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: yatri-backend-service
                port:
                  number: 80
          - path: /
            pathType: Prefix
            backend:
              service:
                name: yatri-frontend-service
                port:
                  number: 80
```

**Adding HTTPS (TLS) - 3 steps:**

```bash
# 1. Make a self-signed cert (for local testing)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt -subj "/CN=campus.local/O=CampusDevOps"

# 2. Store it in a TLS Secret
kubectl create secret tls campus-tls-cert --cert=tls.crt --key=tls.key

# 3. Reference the secret in the Ingress (see below)
```

```yaml
spec:
  tls:
    - hosts: [portal.campus.local, api.campus.local]
      secretName: campus-tls-cert
  rules: ...
```

`kubectl get ingress` will now show `PORTS 80, 443`.

**Commands:**

```bash
minikube addons enable ingress                 # install the controller (Minikube)
kubectl apply -f ingress-routes.yaml
kubectl get ingress                            # or: kubectl get ing
kubectl describe ingress yatri-ingress         # rules + events
kubectl get pods -n ingress-nginx              # is the controller running?

# test without editing /etc/hosts
INGRESS_IP=$(kubectl get ingress campus-ingress-tls -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
curl -k --resolve portal.campus.local:443:$INGRESS_IP https://portal.campus.local/
```

**Remember:**
- Ingress works at **Layer 7 (HTTP/HTTPS)**. It routes by hostname and URL path.
- The `host` must match the `Host` header of the request. Locally, add it to `/etc/hosts` or use `curl --resolve`.
- Backend Services are normally **ClusterIP**. Only the controller needs to be exposed.
- Extra features (rate limiting, auth, CORS, canary %) are set with **annotations** on the Ingress.

**Service types vs Ingress:**

| | NodePort | LoadBalancer | Ingress |
|--|----------|--------------|---------|
| Layer | 4 (TCP) | 4 (TCP) | 7 (HTTP) |
| Public IPs needed | 1 per node | 1 per Service | 1 for everything |
| Host / path routing | No | No | Yes |
| TLS termination | No | No | Yes |
