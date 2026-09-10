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
13. [Pod Lifecycle & Health Probes](#13-pod-lifecycle--health-probes)
14. [ConfigMap & Secret](#14-configmap--secret)
15. [Troubleshooting](#15-troubleshooting)
16. [kubectl Command Reference](#16-kubectl-command-reference)

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

> These two get confused a lot. An init container finishes and exits; a sidecar keeps running. See [13.4](#134-init-containers) for YAML.

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

## 11. Manifests, Labels, Selectors & Namespaces

### 11.1 Anatomy of a Manifest

Every Kubernetes object is described by the same four top-level fields:

```yaml
apiVersion: apps/v1        # which API group/version defines this kind
kind: Deployment           # what type of object
metadata:                  # identity: name, namespace, labels, annotations
  name: nginx-deployment
  labels:
    app: nginx
spec:                      # desired state — differs per kind
  replicas: 3
  ...
```

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

```yaml
# LABEL — lives in metadata, attached to the Pod
metadata:
  labels:
    app: myapp
    tier: backend
    env: prod
```

```yaml
# SELECTOR — lives in spec, "which Pods do I own / send traffic to?"
spec:
  selector:
    matchLabels:        # Deployment / ReplicaSet / DaemonSet / StatefulSet style
      app: myapp
```

```yaml
spec:
  selector:             # Service style — flat map, no matchLabels
    app: myapp
```

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

Or pin it in the manifest:

```yaml
metadata:
  name: myapp
  namespace: dev
```

> Some objects are **cluster-scoped**, not namespaced: Node, Namespace, PersistentVolume, StorageClass, ClusterRole. `kubectl api-resources --namespaced=false` lists them.

Cross-namespace DNS for Services: `<service>.<namespace>.svc.cluster.local`.

---

## 12. Core Kubernetes Objects

### 12.1 Pod

Smallest deployable unit. One or more containers sharing an IP, ports, and volumes.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginx-pod
  labels:
    app: nginx
spec:
  containers:
    - name: nginx
      image: nginx:latest
      ports:
        - containerPort: 80
```

Multi-container Pod (app + sidecar logger — they share `localhost` and volumes):

```yaml
spec:
  containers:
    - name: app
      image: nginx
    - name: logger
      image: busybox
      command: ["sh", "-c", "while true; do echo log; sleep 5; done"]
```

**`restartPolicy`** — what the kubelet does when a container exits:

| Value | Behaviour | Use for |
|-------|-----------|---------|
| `Always` (default) | Restart no matter how it exited | Long-running servers |
| `OnFailure` | Restart only on a non-zero exit | Retryable batch work |
| `Never` | Never restart | One-shot tasks |

A run-once Pod. Without `restartPolicy: Never` it would print, exit, and restart forever (`CrashLoopBackOff`):

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hello-pod
spec:
  restartPolicy: Never
  containers:
    - name: hello
      image: busybox
      command: ["sh", "-c", "echo Hello Kubernetes"]
```

**Resource requests and limits** — tell the Scheduler what a container needs, and cap what it may use:

```yaml
containers:
  - name: app
    image: myapp
    resources:
      requests:          # used by the Scheduler to pick a node
        cpu: "250m"      # 0.25 CPU
        memory: "128Mi"
      limits:            # hard cap enforced on the node
        cpu: "500m"
        memory: "256Mi"  # exceeding this -> container is OOMKilled
```

If no node has enough free capacity for the **requests**, the Pod stays `Pending` forever (see `pod-lifecycle/02-pending.yaml`, which asks for 1000 CPUs).

> **You cannot scale a Pod.** A Pod has no `replicas` field — it *is* one instance. "Scaling" means creating more Pods, which is a controller's job (ReplicaSet / Deployment).
>
> A bare Pod is not self-healing either. Delete it, or lose its node, and it is gone. Use a controller for anything real.

### 12.2 ReplicaSet

Keeps exactly N identical Pods running. This is the object that does the self-healing.

```yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: nginx-rs
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:              # the Pod blueprint it stamps out
    metadata:
      labels:
        app: nginx       # MUST match the selector
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          ports:
            - containerPort: 80
```

The three fields that matter:
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

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:1.25
          ports:
            - containerPort: 80
```

On an image change the Deployment creates a **new** ReplicaSet and shifts Pods over gradually — old RS scales down, new RS scales up. The old one is kept at 0 replicas so `kubectl rollout undo` can reverse it.

```
Deployment -> ReplicaSet (v2, 3 pods)
           +- ReplicaSet (v1, 0 pods)   <- kept for rollback
```

**Update strategies**

```yaml
spec:
  strategy:
    type: RollingUpdate          # default
    rollingUpdate:
      maxSurge: 1                # how many EXTRA pods may exist during the update
      maxUnavailable: 0          # how many pods may be DOWN during the update
```

| Strategy | Behaviour | Downtime |
|----------|-----------|----------|
| `RollingUpdate` (default) | Replace Pods a few at a time, controlled by `maxSurge` / `maxUnavailable` (numbers or percentages, default 25% each) | None |
| `Recreate` | Kill **all** old Pods, then create the new ones | Yes — use only when two versions cannot coexist (e.g. a DB schema change) |

With `maxSurge: 1, maxUnavailable: 0` a rollout is safest: one new Pod comes up, must become Ready, then one old Pod goes away. If the new image is broken (`ImagePullBackOff`), the rollout **stalls** but the old Pods keep serving — see `troubleshooting/broken-image.yaml` and [15.3](#153-rollout-failures--rollback).

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

**Default choice for stateless apps.**

### 12.4 Service

Pods get a new IP every time they are recreated, so you never talk to a Pod IP. A Service gives a **stable name and IP** in front of a set of Pods (selected by label) and load-balances across them.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
spec:
  type: NodePort
  selector:
    app: myapp          # matches Pod labels, not the Deployment name
  ports:
    - port: 80          # the Service's own port
      targetPort: 8080  # the container port it forwards to
      nodePort: 30080   # port opened on every node (30000-32767)
```

**Service types**

| Type | Reachable from | Notes |
|------|----------------|-------|
| `ClusterIP` (default) | Inside the cluster only | Service-to-service traffic |
| `NodePort` | `<node-ip>:<nodePort>` | Opens the same port on every node; range 30000–32767 |
| `LoadBalancer` | Public IP | Cloud provider creates a real LB; on Minikube needs `minikube tunnel` |
| `ExternalName` | — | Just a DNS CNAME to an external host |

Inside the cluster a Service is reachable by DNS: `myapp-service` (same namespace), or `myapp-service.<namespace>.svc.cluster.local` across namespaces.

On Minikube: `minikube service myapp-service --url`.

**The four kinds of "port"**

This is the most common source of confusion. There are four different port fields, on two different objects:

| Field | Lives on | Meaning |
|-------|----------|---------|
| `containerPort` | Pod (container spec) | The port the **application inside the container** listens on. Mostly documentation — it does not publish anything by itself |
| `targetPort` | Service | The Pod port the Service **forwards to**. Should equal `containerPort` (or the app's real listening port) |
| `port` | Service | The port the **Service itself** listens on. Other Pods call `http://my-service:<port>` |
| `nodePort` | Service (`type: NodePort` only) | The port opened on **every node's IP**, range 30000–32767. Auto-assigned if omitted |

```yaml
# Pod side
containers:
  - name: backend
    image: myapp
    ports:
      - containerPort: 8080      # app listens here
```

```yaml
# Service side
spec:
  type: NodePort
  ports:
    - port: 80                    # Service listens here
      targetPort: 8080            # ...and forwards to the Pod here
      nodePort: 30080             # ...reachable from outside on every node here
```

Traffic from **outside** the cluster (NodePort):

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

Traffic from **another Pod** inside the cluster (ClusterIP path — nodePort not involved):

```
Other Pod
   |  http://my-service:80     (port)
   v
Service :80
   |  forwards to :8080        (targetPort)
   v
Pod :8080                      (containerPort)
```

Shortcut: if you omit `targetPort`, it defaults to the same value as `port`. So `port: 80` with an app on 80 needs nothing else.

**Debugging a Service**

```bash
kubectl get svc
kubectl describe svc myapp-service        # look at the Endpoints line
kubectl get endpoints myapp-service       # empty? -> selector doesn't match any Pod labels
```

### 12.5 DaemonSet

Runs **one copy of a Pod on every node**, including any node added later. There is no `replicas` field — the node count is the replica count.

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: node-exporter
spec:
  selector:
    matchLabels:
      app: node-exporter
  template:
    metadata:
      labels:
        app: node-exporter
    spec:
      containers:
        - name: node-exporter
          image: prom/node-exporter
          ports:
            - containerPort: 9100
```

Used for per-node agents: log collectors (Fluentd), metrics exporters, monitoring, CNI plugins, storage daemons.

```bash
kubectl get ds -A                          # kube-proxy and the CNI are DaemonSets in kube-system
```

### 12.6 StatefulSet

For stateful apps (databases, Kafka) where each Pod needs a **stable identity and its own storage**.

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  serviceName: "mysql"   # required headless Service (clusterIP: None)
  replicas: 3
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
        - name: mysql
          image: mysql:5.7
          ports:
            - containerPort: 3306
          env:
            - name: MYSQL_ROOT_PASSWORD
              value: "password"
          volumeMounts:
            - name: mysql-persistent-storage
              mountPath: /var/lib/mysql
  volumeClaimTemplates:                  # one PVC created per Pod
    - metadata:
        name: mysql-persistent-storage
      spec:
        accessModes: [ "ReadWriteOnce" ]
        resources:
          requests:
            storage: 5Gi
```

How it differs from a Deployment:

| | Deployment | StatefulSet |
|--|-----------|-------------|
| Pod names | random (`myapp-7d9f-x2k`) | ordered (`mysql-0`, `mysql-1`, `mysql-2`) |
| Identity after restart | new name, new IP | **same name**, same storage |
| Storage | shared or none | one PVC per Pod via `volumeClaimTemplates` |
| Start / stop order | all at once | one at a time, in order (reverse on delete) |
| Service | optional | **requires** a headless Service (`serviceName`) |
| DNS per Pod | no | yes: `mysql-0.mysql.<ns>.svc.cluster.local` |

> `MYSQL_ROOT_PASSWORD` in plain text is fine for learning only — in reality that belongs in a **Secret** (see [14](#14-configmap--secret)).

### 12.7 Which Object to Use

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

## 13. Pod Lifecycle & Health Probes

Hands-on lab for every case in this section: `Kubernetes_Objects/pod-lifecycle/` (run `kubectl get pods -w` in one terminal and apply the numbered files from another).

### 13.1 Pod Phases

`kubectl get pods` shows the Pod **phase** in the STATUS column (plus some more specific reasons — see 13.2):

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

### 13.2 Container States and the STATUS column

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

### 13.3 Health Probes

The kubelet runs three kinds of probes against a container. Each can be an `httpGet`, a `tcpSocket`, or an `exec` command.

| Probe | Question it answers | On failure |
|-------|--------------------|------------|
| **startupProbe** | "Has the app finished starting?" | Kill and restart the container. While it runs, the other two probes are **disabled** — protects slow starters from being killed by an impatient liveness probe |
| **readinessProbe** | "Can this container serve traffic *right now*?" | Pod is marked **Not Ready** and **removed from Service endpoints**. Container is **not** restarted |
| **livenessProbe** | "Is the app still alive, or wedged?" | Kill and **restart** the container (obeying `restartPolicy`) |

```yaml
containers:
  - name: app
    image: myapp
    ports:
      - containerPort: 8080
    startupProbe:
      httpGet: { path: /healthz, port: 8080 }
      periodSeconds: 5
      failureThreshold: 30        # up to 150 s to start
    readinessProbe:
      httpGet: { path: /ready, port: 8080 }
      initialDelaySeconds: 5
      periodSeconds: 5
    livenessProbe:
      exec:
        command: ["sh", "-c", "test -f /tmp/healthy"]
      periodSeconds: 10
      failureThreshold: 3
```

Common tuning fields:

| Field | Default | Meaning |
|-------|---------|---------|
| `initialDelaySeconds` | 0 | Wait before the first probe |
| `periodSeconds` | 10 | How often to probe |
| `timeoutSeconds` | 1 | How long one probe may take |
| `failureThreshold` | 3 | Consecutive failures before acting |
| `successThreshold` | 1 | Consecutive successes to be considered healthy again (only readiness may be >1) |

> **Readiness vs liveness in one sentence:** readiness takes the Pod *out of the load balancer*; liveness *restarts* it. A Pod can be `Running` but `0/1 READY` — that means the readiness probe is failing, and the Service will not send it traffic.

### 13.4 Init Containers

Run **before** the app containers, **in order**, each to completion. If one fails, the kubelet retries it (per `restartPolicy`) and the app containers never start.

```yaml
spec:
  initContainers:
    - name: wait-for-db
      image: busybox:1.36
      command: ["sh", "-c", "until nc -z mysql 3306; do echo waiting; sleep 2; done"]
  containers:
    - name: app
      image: nginx:1.27
```

While init containers run, STATUS shows `Init:0/1`, then `PodInitializing`, then `Running`.

### 13.5 Graceful Termination

When a Pod is deleted (or replaced during a rollout):

```
1. Pod marked Terminating; removed from Service endpoints (no new traffic)
2. preStop hook runs (if defined)
3. SIGTERM sent to PID 1 of every container
4. Wait up to terminationGracePeriodSeconds (default 30s)
5. SIGKILL anything still running
```

```yaml
spec:
  terminationGracePeriodSeconds: 20
  containers:
    - name: app
      image: myapp
      lifecycle:
        preStop:
          exec:
            command: ["sh", "-c", "sleep 5"]   # let in-flight requests drain
```

> Your app must **handle SIGTERM** (close connections, flush, exit 0) to shut down cleanly. If it runs under a shell (`sh -c "..."`) the shell may swallow the signal — use `exec` or a `trap` (see `pod-lifecycle/12-termination.yaml`).

Force-delete a stuck Pod (last resort, skips the grace period):

```bash
kubectl delete pod <pod> --grace-period=0 --force
```

---

## 14. ConfigMap & Secret

Keep configuration out of the image so the same image runs in dev, staging, and prod.

| | ConfigMap | Secret |
|--|-----------|--------|
| For | Non-sensitive config: URLs, feature flags, config files | Passwords, API tokens, TLS certs |
| Stored as | Plain text | **base64-encoded** (not encrypted by default — enable encryption at rest / use RBAC) |
| Size limit | 1 MiB | 1 MiB |

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  APP_ENV: "production"
  LOG_LEVEL: "info"
---
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
type: Opaque
stringData:                 # plain text here; Kubernetes base64-encodes it for you
  MYSQL_ROOT_PASSWORD: "password"
```

Two ways to consume them in a Pod:

```yaml
containers:
  - name: app
    image: myapp
    env:                                   # 1. as individual environment variables
      - name: APP_ENV
        valueFrom:
          configMapKeyRef:
            name: app-config
            key: APP_ENV
      - name: MYSQL_ROOT_PASSWORD
        valueFrom:
          secretKeyRef:
            name: db-secret
            key: MYSQL_ROOT_PASSWORD
    envFrom:                               # ...or all keys at once
      - configMapRef:
          name: app-config
    volumeMounts:                          # 2. as files in a directory
      - name: config-vol
        mountPath: /etc/config
volumes:
  - name: config-vol
    configMap:
      name: app-config
```

```bash
kubectl create configmap app-config --from-literal=APP_ENV=prod --from-file=app.properties
kubectl create secret generic db-secret --from-literal=MYSQL_ROOT_PASSWORD=password
kubectl get secret db-secret -o jsonpath='{.data.MYSQL_ROOT_PASSWORD}' | base64 -d
```

> Env vars are read once at container start — changing a ConfigMap does **not** update a running Pod's environment. Mounted files *do* update (with a delay), but the app has to re-read them. Simplest fix: `kubectl rollout restart deploy/<name>`.

---

## 15. Troubleshooting

### 15.1 The Debugging Order

Always in this order — each step tells you where to look next:

```
1. kubectl get pods -o wide            -> which Pod, what STATUS, how many RESTARTS, which node
2. kubectl describe pod <pod>          -> Events at the bottom: scheduling, image pull, probe failures
3. kubectl logs <pod> [-c <container>] -> what the app itself said
   kubectl logs <pod> --previous       -> logs of the crashed container before the restart
4. kubectl exec -it <pod> -- sh        -> poke around inside (env, files, curl localhost)
5. kubectl get events --sort-by=.metadata.creationTimestamp   -> cluster-wide timeline
```

### 15.2 Common Pod Errors

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

### 15.3 Rollout Failures & Rollback

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

### 15.4 Service Not Reachable

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

Checklist: selector ≠ labels, `targetPort` ≠ the port the app listens on, readiness probe failing (Pod not in endpoints), wrong namespace.

### 15.5 Deleting Things That Come Back

Deleting a Pod owned by a ReplicaSet/Deployment does nothing lasting — the controller recreates it immediately. Delete the **owner**:

```bash
kubectl get pod <pod> -o jsonpath='{.metadata.ownerReferences[0].kind}/{.metadata.ownerReferences[0].name}'
kubectl delete deploy <name>         # removes the Deployment, its ReplicaSets, and their Pods
```

---

## 16. kubectl Command Reference

`kubectl` is the command-line interface to the cluster. Every command is an HTTPS request to the **kube-apiserver**, which is why the same commands work on Minikube, kind, EKS, GKE, and AKS.

General shape:

```
kubectl <verb> <resource> [<name>] [flags]
        get     pods       nginx    -n dev -o wide
```

### 16.1 Cluster Info & Context

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

### 16.2 Get (list resources)

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

### 16.3 Describe (detailed info + Events)

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

### 16.4 Create / Apply / Delete

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

### 16.5 Logs & Exec (troubleshooting inside a Pod)

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

### 16.6 Port Forwarding

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

### 16.7 Scaling & Rollouts

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

### 16.8 YAML Generation, Dry Run & Explain

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

### 16.9 Namespaces

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

### 16.10 Edit, Patch, Label, Annotate (change live objects)

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

### 16.11 Short Names & Output Formats

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

### 16.12 Quality-of-Life

```bash
alias k=kubectl                                  # bash / zsh
Set-Alias -Name k -Value kubectl                 # PowerShell

source <(kubectl completion bash)                # tab completion (bash)
kubectl completion powershell | Out-String | Invoke-Expression   # PowerShell

kubectl get pods -w                              # watch live while applying files elsewhere
watch kubectl get pods                           # Linux/Mac alternative
```
