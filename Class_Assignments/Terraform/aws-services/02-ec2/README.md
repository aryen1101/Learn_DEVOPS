# 02. EC2 - Compute

#### What is EC2?

EC2 (Elastic Compute Cloud) provides virtual servers, called instances, in AWS. The user chooses the operating system, the size (CPU and memory), the storage and the network settings, and the instance is running within about a minute. Billing is per second while the instance runs; a stopped instance is charged only for its disk.

```text
              AMI  (which operating system?)
               ↓
        INSTANCE TYPE  (how much CPU and memory?)
               ↓
   ┌─────────  EC2 INSTANCE  ─────────┐
   |                                  |
 KEY PAIR                       SECURITY GROUP
 (how to log in)                (who can connect)
   |                                  |
   └───────────  EBS  ────────────────┘
              (the hard disk)
```

**Problem EC2 solves.** Running a server used to mean buying hardware, installing it, and waiting weeks. With EC2 a server is created in minutes, resized when needed, and deleted when no longer required, with no upfront cost.

#### AMI

An AMI (Amazon Machine Image) is the template an instance is launched from. It contains the operating system and any software that was pre installed on it.

```text
AMI: Amazon Linux 2023   → instance boots with Amazon Linux
AMI: Ubuntu 24.04        → instance boots with Ubuntu
AMI: my-web-server-v1    → instance boots with Ubuntu + nginx + application already installed
```

Sources of AMIs:

* **AWS provided** images such as Amazon Linux, Ubuntu and Windows Server.
* **Marketplace** images with software already configured.
* **Custom** images created from a configured instance. One instance is set up once, saved as an AMI, and identical copies are launched from it. This is the basis of auto scaling.

> AMI = the image (OS plus software) that an instance is created from.

#### Instance types

The instance type defines the hardware of the instance: number of vCPUs, memory, storage and network performance. The name is read as family, generation and size:

```text
t3.micro
│ │  └── size        (nano, micro, small, medium, large, xlarge, 2xlarge ...)
│ └───── generation  (higher number = newer hardware)
└─────── family      (what the instance is optimised for)
```

| Family | Optimised for | Example |
| :--- | :--- | :--- |
| t | General purpose, burstable CPU, lowest cost, free tier | t2.micro, t3.micro |
| m | Balanced CPU and memory | m6i.large |
| c | Compute intensive work (builds, batch, gaming servers) | c6i.xlarge |
| r | Memory intensive work (databases, caches) | r6g.large |
| g, p | GPU workloads (machine learning, graphics) | g5.xlarge |

#### Key pairs

A key pair is the SSH credential used to log in to a Linux instance. AWS stores the public key on the instance; the private key (`.pem` file) is downloaded once, at creation time, and cannot be downloaded again.

```bash
chmod 400 my-key.pem
ssh -i my-key.pem ec2-user@<public-ip>
```

```text
Private key lost  →  SSH access to that instance is lost
```

> Key pair = the SSH key for logging in. Download once and store safely.

#### Security Groups

A security group is a virtual firewall attached to an instance. It controls traffic with inbound rules (what may come in) and outbound rules (what may go out).

```text
Internet  ──►  Security Group  ──►  EC2 instance
               (checks the rules)
```

Default behaviour:

```text
Inbound  → all traffic blocked
Outbound → all traffic allowed
```

Typical rules for a web server:

| Type | Port | Source | Purpose |
| :--- | :--- | :--- | :--- |
| SSH | 22 | Administrator's IP only | Remote login |
| HTTP | 80 | 0.0.0.0/0 | Public website |
| HTTPS | 443 | 0.0.0.0/0 | Public website |

Security groups are **stateful**: if an inbound request is allowed, the response is allowed out automatically. They contain only Allow rules. Opening port 22 to `0.0.0.0/0` is a common and dangerous mistake.

> Security Group = instance level firewall with Allow rules only.

#### EBS

EBS (Elastic Block Store) provides the block storage volumes that act as the hard disks of an instance. The root volume holds the operating system; additional volumes can be attached for data.

```text
EC2 instance  ──attached──►  EBS volume
```

Key behaviour:

```text
Instance stopped      → volume and data remain
Instance terminated   → root volume deleted by default (configurable)
Snapshot taken        → point in time backup stored in S3
```

Volume types: `gp3` (general purpose SSD, the default choice), `io2` (high IOPS for demanding databases), `st1` (low cost HDD for large sequential workloads).

> EBS = persistent disk storage for EC2 instances.

#### Public vs private IP

| | Private IP | Public IP | Elastic IP |
| :--- | :--- | :--- | :--- |
| Reachable from | Inside the VPC only | The internet | The internet |
| Assigned to | Every instance | Instances in a public subnet with auto assign enabled | Allocated manually and attached |
| Changes on stop/start | No | Yes | No |
| Cost | Free | Free while attached | Small charge when not attached |

Guideline:

```text
Web server   → public IP, or private IP behind a load balancer
Database     → private IP only, never reachable from the internet
```

#### Instance lifecycle

```text
pending → running → stopping → stopped → (start) → pending → running
                  → shutting-down → terminated
```

| State | Billing | Data |
| :--- | :--- | :--- |
| Running | Compute and storage | Intact |
| Stopped | Storage only | Intact, public IP released |
| Terminated | None | Root volume deleted by default |

A reboot keeps the same IPs and disk, like restarting a physical computer. Stopping development instances outside working hours is a simple way to reduce cost.

#### Common use cases

* Hosting websites, APIs and application backends.
* CI/CD servers such as Jenkins or self hosted GitHub Actions runners.
* Bastion (jump) hosts to reach servers in private subnets.
* Batch processing and data jobs.
* Worker nodes of a Kubernetes cluster.
* Development and test environments that run only when needed.

#### Summary

| Concept | Meaning |
| :--- | :--- |
| AMI | Image the instance boots from |
| Instance type | Hardware size and family |
| Key pair | SSH key for login |
| Security Group | Instance firewall |
| EBS | Persistent disk |
| Private IP | Address inside the VPC |
| Public IP | Internet address, changes on restart |
| Elastic IP | Fixed public address |

```text
AMI            = what it runs
Instance type  = how big it is
Key pair       = how I get in
Security group = who else can get in
EBS            = where the data lives
```
