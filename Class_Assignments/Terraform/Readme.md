# Terraform & Infrastructure as Code


---

## Task 1: Terraform S3 Demo

Project folder: `terraform-s3-demo/`

```text
terraform-s3-demo/
├── terraform.tf
├── providers.tf
├── variables.tf
├── terraform.tfvars
├── main.tf
├── outputs.tf
├── .gitignore
└── README.md
```

### terraform init

```bash
terraform init
```

### terraform fmt

```bash
terraform fmt
```

### terraform validate

```bash
terraform validate
```

![fmt and validate](images/image-1.png)
![validate](images/image-2.png)

### terraform plan

```bash
terraform plan
```

![terraform plan](images/image-3.png)
![terraform plan](images/image-4.png)

### terraform apply

```bash
terraform apply
```

![terraform apply](images/image-5.png)
![terraform apply](images/image-6.png)
![terraform apply](images/image-7.png)

### terraform show

```bash
terraform show
```

### terraform output

```bash
terraform output
```

### terraform destroy

```bash
terraform plan -destroy
terraform destroy
```

![plan destroy](images/image-8.png)
![plan destroy](images/image-9.png)
![terraform destroy](images/image-10.png)
![terraform destroy](images/image-11.png)

---

## Task 2: AWS Services Research

### 01. IAM - Governance

#### What is IAM?

IAM (Identity and Access Management) is the AWS service that controls **who** can access an AWS account and **what** they are allowed to do. Every request to AWS, whether from the console, the CLI or a tool like Terraform, is checked by IAM before it is executed. IAM is free and global, so identities and rules created once apply in every region.

```text
                 AWS ACCOUNT
                     |
                    IAM
                     |
        ┌────────────┼────────────┐
        ↓            ↓            ↓
      USER         GROUP         ROLE
        |            |            |
        └────────────┼────────────┘
                     ↓
                  POLICY
                     ↓
          "What are you allowed to do?"
```

**Problem IAM solves.** A single AWS account is shared by many people and programs. Without IAM, everyone would have full access to everything. IAM lets each identity get only the access it needs:

```text
Developer A → can use S3
Developer B → can use EC2
Developer C → can only view resources
Admin       → can do everything
```

IAM answers two questions:

```text
WHO are you?        → Identity   (User, Role)
WHAT can you do?    → Permission (Policy)
```

#### Users

An IAM user is an identity for one person or one application. Each user has its own credentials:

| Credential | Used for |
| :--- | :--- |
| Username and password | AWS Management Console |
| Access Key ID and Secret Access Key | AWS CLI, SDKs, Terraform |

When `aws configure` is run, the access key pair entered belongs to an IAM user. From that point every CLI and Terraform call is made as that user.

The root user, created with the account email, has unrestricted access and should not be used for daily work. It should be protected with MFA and used only for account level tasks.

> User = a long term identity for a person or an application.

#### Groups

A group is a collection of users. Policies are attached to the group, and every user in the group inherits them. This avoids attaching the same policies to many users one by one.

```text
Developers (group)            ReadOnly (group)
├── Aryen                     └── Auditor
├── Rahul
└── Priya
     ↓                              ↓
S3 and EC2 policies           ViewOnly policy
```

Rules:

* A group contains users only. It cannot contain roles or other groups.
* A group cannot be used to log in. It is only a way to manage permissions.
* A user can belong to several groups.

> Group = a set of users that share the same permissions.

#### Roles

A role is an identity with permissions but **no permanent credentials**. An AWS service, an application or a user *assumes* the role and receives temporary credentials that expire automatically (by default after one hour).

The problem roles solve:

```text
Without a role                      With a role
EC2                                 EC2
 | access key stored on disk         ↓ assumes
 ↓                                  IAM Role → Policy
S3                                   ↓
                                    S3 (temporary credentials)
```

Storing a permanent access key on a server is dangerous because anyone who gets into the server gets the key. A role removes the stored key completely.

Roles are used when:

* An EC2 instance needs to read or write S3.
* A Lambda function needs to access DynamoDB.
* A CI/CD pipeline needs to deploy to AWS.
* A user in one AWS account needs access to another account (cross account access).
* A user needs elevated permissions for a short time.

**User vs Role**

| | User | Role |
| :--- | :--- | :--- |
| Represents | A person or application | A job that can be taken on temporarily |
| Credentials | Permanent (password, access keys) | Temporary, issued when assumed |
| Typical use | Humans | EC2, Lambda, ECS, pipelines, cross account |

> Role = an identity that is assumed temporarily to get permissions.

#### Policies

A policy is a JSON document that defines permissions. It is attached to users, groups or roles.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::my-bucket/*"
    }
  ]
}
```

Every statement has three main parts:

| Part | Meaning | Example |
| :--- | :--- | :--- |
| Effect | Allow or Deny | `Allow` |
| Action | The AWS API operation | `s3:GetObject`, `ec2:StartInstances` |
| Resource | The ARN the statement applies to | `arn:aws:s3:::my-bucket/*` |

Read as a sentence: *Allow s3:GetObject on my-bucket* means "this identity may read objects from my-bucket".

Types of policies:

* **AWS managed** policies are written by AWS, for example `AmazonS3ReadOnlyAccess` or `AdministratorAccess`.
* **Customer managed** policies are written by the account owner for exact control.
* **Inline** policies are embedded in one user, group or role and are not reusable.

> Policy = a JSON document that lists what actions are allowed or denied on which resources.

#### Permissions

Permissions are the effective rights an identity ends up with after all of its policies (its own, its groups' and any assumed role's) are combined.

A new user starts with no permissions. For every request AWS evaluates:

```text
1. Is there an explicit DENY in any policy?   → request is denied
2. Is there an ALLOW?                         → request is allowed
3. Neither                                    → denied by default
```

An explicit Deny always overrides an Allow.

Example from Task 1 of this assignment:

```text
terraform apply
   ↓
AWS credentials from `aws configure`
   ↓
IAM identifies the user
   ↓
IAM checks: is s3:CreateBucket allowed on this bucket?
   ↓
No matching Allow → AccessDenied
```

The error `not authorized to perform: s3:CreateBucket` did not mean Terraform was broken. It meant the IAM user running Terraform had no policy allowing that action.

#### Least privilege

Least privilege means granting only the permissions required for a task and nothing more.

```text
Bad      s3:*                                 full access to every bucket
Better   s3:GetObject                         read only, but every bucket
Best     s3:GetObject on arn:aws:s3:::reports/*   read only, one bucket
```

If credentials with least privilege leak, the damage is limited to that one task. The practical approach is to start with no permissions and add them as a specific action is needed.

#### IAM best practices

1. Do not use the root user for daily work. Create an IAM user and lock the root user away.
2. Enable MFA on the root user and on every user with console access.
3. Attach policies to groups, not to individual users.
4. Use roles for EC2, Lambda, ECS and CI/CD instead of access keys.
5. Apply least privilege and review permissions regularly.
6. Rotate access keys and delete keys that are no longer used.
7. Never store access keys in code, in git, in screenshots or in chat messages.
8. Enable CloudTrail so every API call is recorded with the identity that made it.

#### Common use cases

| Situation | IAM solution |
| :--- | :--- |
| Each team member needs their own login | IAM user placed in a group with the right policies |
| EC2 instance must read files from S3 | IAM role attached to the instance |
| CI/CD pipeline deploys to AWS | Limited IAM user or an OIDC role for the pipeline |
| Development account needs access to production account | Cross account role |
| Auditor must view but not change anything | User in a read only group |
| Developer needs admin access for one hour | Assume an admin role with a session limit |

#### Summary

| Concept | Meaning |
| :--- | :--- |
| User | Long term identity for a person or application |
| Group | Collection of users sharing permissions |
| Role | Identity assumed temporarily by services, users or applications |
| Policy | JSON document that allows or denies actions on resources |
| Permission | The effective rights after all policies are combined |
| Least privilege | Grant only what the task requires |

```text
User   = who I am
Group  = who I belong with
Role   = who I can temporarily become
Policy = what I can do
IAM    = the system that controls all of this
```

### 02. EC2 - Compute

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

### 03. S3 - Storage

#### What is S3?

S3 (Simple Storage Service) is object storage. Files are uploaded into buckets, stored redundantly across several data centres in a region, and retrieved from anywhere over HTTPS. There is no disk to size and no server to manage, and capacity is unlimited. Billing is based on storage used and requests made.

```text
          S3
           |
       BUCKET   (container with a globally unique name)
           |
    ┌──────┼──────┐
    ↓      ↓      ↓
 OBJECT  OBJECT  OBJECT   (files plus metadata)
```

S3 is not a disk that a server mounts (that is EBS). It is storage that applications read and write through an API.

**Problem S3 solves.** Storing uploads or backups on a server's own disk means the disk fills up, the data is lost if the server fails, and other servers cannot see it. S3 removes all three problems.

#### Buckets

A bucket is the top level container for objects. In Task 1 of this assignment the bucket `aryen1101` was created with Terraform.

Rules:

* The name must be unique across **all** AWS accounts, not just the owner's account.
* Names are lowercase and may contain letters, numbers, dots and hyphens, 3 to 63 characters.
* A bucket is created in one region, but its name is global.
* A new bucket is private. Nothing can read it until a policy or IAM permission allows it.

```bash
aws s3 mb s3://aryen1101 --region ap-south-1
aws s3 ls
```

> Bucket = a container for objects with a globally unique name.

#### Objects

An object is a file together with its metadata.

```text
Object
├── Key       → photos/2024/trip.jpg   (full name, including the "path")
├── Data      → the file content, 0 bytes to 5 TB
└── Metadata  → content type, size, last modified, tags
```

S3 has no real folders. The `/` characters are part of the key; the console displays them as folders for convenience.

```bash
aws s3 cp trip.jpg s3://aryen1101/photos/2024/trip.jpg
aws s3 ls s3://aryen1101/photos/2024/
aws s3 rm s3://aryen1101/photos/2024/trip.jpg
```

> Object = one file in a bucket, identified by its key.

#### Storage classes

Storage classes offer different prices depending on how often data is accessed.

| Class | Use when | Trade off |
| :--- | :--- | :--- |
| Standard | Data accessed frequently | Highest storage price, no retrieval fee |
| Intelligent-Tiering | Access pattern unknown | Small monitoring fee; AWS moves objects automatically |
| Standard-IA | Accessed about once a month, needed quickly | Lower storage price, fee per retrieval |
| One Zone-IA | Same as above, but data that can be recreated | Stored in one Availability Zone only |
| Glacier Instant / Flexible | Archives and long term backups | Very low price, retrieval takes minutes to hours |
| Glacier Deep Archive | Compliance data rarely accessed | Lowest price, retrieval up to 12 hours |

#### Versioning

With versioning enabled, S3 keeps every version of an object instead of replacing it.

```text
Versioning OFF                          Versioning ON
upload report.pdf (v1)                  upload report.pdf (v1)
upload report.pdf (v2) → v1 lost        upload report.pdf (v2) → v1 kept
delete report.pdf      → gone           delete report.pdf      → delete marker added, v1 and v2 kept
```

Versioning protects against accidental overwrites and deletions. Because all versions use storage, it is usually combined with a lifecycle rule that removes old versions.

#### Lifecycle policies

A lifecycle policy applies actions to objects automatically after a set number of days.

```text
Day 0    → stored in Standard
Day 30   → transition to Standard-IA
Day 90   → transition to Glacier
Day 365  → expire (delete)
```

Lifecycle rules keep cost down for logs, backups and old versions without manual clean up.

#### Encryption

| | Method |
| :--- | :--- |
| At rest | Enabled by default with SSE-S3 (AES-256, AWS managed key). SSE-KMS uses a customer owned KMS key and records every key use in CloudTrail. |
| In transit | HTTPS. A bucket policy can deny requests made over plain HTTP. |

In the `terraform plan -destroy` output of Task 1, the bucket showed `sse_algorithm = "AES256"`, which is the default SSE-S3 encryption.

#### Bucket policies

A bucket policy is a JSON permission document attached to the bucket. IAM policies describe what an identity may do; a bucket policy describes what may be done to this bucket, including by anonymous users.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::my-website-bucket/*"
    }
  ]
}
```

This policy allows anyone (`Principal: *`) to read objects, which is how a static website is served. **Block Public Access** is enabled on new buckets by default and prevents such a policy from taking effect until it is deliberately turned off.

#### Common use cases

* Backups and database dumps.
* Static website hosting (HTML, CSS, JavaScript, images).
* Application, CloudTrail and load balancer logs.
* User uploads such as images and documents.
* Data lake for analytics with Athena or Glue.
* Terraform remote state shared by a team.

#### Summary

| Concept | Meaning |
| :--- | :--- |
| Bucket | Container with a globally unique name |
| Object | File plus metadata, identified by its key |
| Storage class | Price tier based on access frequency |
| Versioning | Keeps every version of an object |
| Lifecycle policy | Automatic transition or deletion after N days |
| Encryption | SSE-S3 by default at rest, HTTPS in transit |
| Bucket policy | JSON access rules attached to the bucket |

```text
Bucket     = the drawer
Object     = the file inside
Class      = how far away the drawer is
Versioning = keep old copies
Lifecycle  = automatic clean up
Policy     = who may open the drawer
```

### 04. VPC - Networking

#### What is VPC?

A VPC (Virtual Private Cloud) is a private, isolated network inside AWS. Resources such as EC2 instances and RDS databases are launched into a VPC. The owner defines the IP range, divides it into subnets, and controls which parts can reach or be reached from the internet. Every account has a default VPC per region; production workloads normally use a custom VPC.

```text
                      INTERNET
                          |
                   Internet Gateway
                          |
   ┌──────────────────  VPC 10.0.0.0/16  ──────────────────┐
   |                                                        |
   |  PUBLIC SUBNET 10.0.1.0/24      PRIVATE SUBNET 10.0.2.0/24
   |  route 0.0.0.0/0 → IGW          route 0.0.0.0/0 → NAT
   |  ├── Load balancer              ├── Application servers
   |  ├── Bastion host               └── Database
   |  └── NAT Gateway  ───────────────────────┘
   |                                                        |
   └────────────────────────────────────────────────────────┘
```

**Problem VPC solves.** Without a network design every server would be exposed to the internet. A VPC places public facing components in public subnets and keeps application servers and databases in private subnets that the internet cannot reach.

#### CIDR

CIDR (Classless Inter-Domain Routing) notation defines an IP range.

```text
10.0.0.0/16
         └── first 16 bits fixed, remaining 16 bits available → 65,536 addresses
```

| CIDR | Addresses | Usable in AWS | Typical use |
| :--- | :--- | :--- | :--- |
| /16 | 65,536 | 65,531 | Whole VPC |
| /24 | 256 | 251 | One subnet |
| /28 | 16 | 11 | Smallest subnet allowed |

AWS reserves 5 addresses in every subnet. A smaller number after the slash means a larger range. Private ranges (`10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`) are used, and the range must not overlap with other networks that may be connected later. A VPC's CIDR cannot be changed after creation, only extended.

#### Subnets

A subnet is a portion of the VPC's IP range located in exactly one Availability Zone.

```text
VPC 10.0.0.0/16
├── 10.0.1.0/24    AZ-a   public
├── 10.0.2.0/24    AZ-b   public
├── 10.0.11.0/24   AZ-a   private
└── 10.0.12.0/24   AZ-b   private
```

Creating subnets in at least two Availability Zones keeps the application running if one zone fails. A subnet is public or private only because of the route table attached to it.

#### Route tables

A route table contains rules that decide where network traffic is sent based on its destination. Every subnet is associated with exactly one route table.

```text
Public route table                  Private route table
10.0.0.0/16 → local                 10.0.0.0/16 → local
0.0.0.0/0   → Internet Gateway      0.0.0.0/0   → NAT Gateway
```

The `local` route exists in every table and allows all resources in the VPC to communicate with each other.

#### Internet Gateway

An Internet Gateway (IGW) connects the VPC to the internet. There is one per VPC, and it scales automatically.

```text
VPC  ◄────  Internet Gateway  ────►  Internet
```

For an instance to be reachable from the internet, three conditions must all be met:

```text
1. Its subnet's route table sends 0.0.0.0/0 to the IGW
2. It has a public IP or Elastic IP
3. Its security group allows the inbound port
```

#### NAT Gateway

A NAT (Network Address Translation) Gateway allows instances in private subnets to reach the internet for updates and external API calls, while preventing the internet from initiating connections to them.

```text
Private instance ──► NAT Gateway ──► Internet Gateway ──► Internet    allowed (outbound)
Internet ─────────► NAT Gateway ──X                                    blocked (inbound)
```

The NAT Gateway is placed in a public subnet with an Elastic IP, and the private route table points `0.0.0.0/0` to it. It is billed per hour and per gigabyte.

> NAT Gateway = one way exit for private subnets.

#### Security Groups

A security group is a stateful firewall at the instance level. It contains Allow rules only, and an allowed inbound request automatically permits the response. Rules can reference other security groups rather than IP addresses:

```text
database-sg: allow port 3306 from web-server-sg
```

This is the main mechanism for controlling which tier of an application may talk to which.

#### Network ACLs

A Network ACL (NACL) is a firewall at the subnet level. Every subnet has one; the default allows all traffic.

| | Security Group | Network ACL |
| :--- | :--- | :--- |
| Level | Instance | Subnet |
| Rule types | Allow only | Allow and Deny |
| Stateful | Yes | No, inbound and outbound rules are separate |
| Evaluation | All rules considered | Numbered order, first match wins |
| Default | Deny all inbound | Allow all |

Security groups handle most traffic control. NACLs are useful for blocking a specific IP address from an entire subnet.

#### Public vs private subnet

| | Public subnet | Private subnet |
| :--- | :--- | :--- |
| Route for 0.0.0.0/0 | Internet Gateway | NAT Gateway, or none |
| Instances receive public IP | Yes | No |
| Reachable from the internet | Yes, if the security group allows | No |
| Can reach the internet | Yes | Only through a NAT Gateway |
| Typical resources | Load balancers, bastion hosts, NAT Gateway | Application servers, databases, caches |

Only resources that must be reached directly from the internet belong in a public subnet. Everything else is placed in private subnets behind a load balancer.

#### Summary

| Concept | Meaning |
| :--- | :--- |
| VPC | Isolated private network in AWS |
| CIDR | IP range notation, e.g. 10.0.0.0/16 |
| Subnet | Slice of the range in one Availability Zone |
| Route table | Rules for where traffic is sent |
| Internet Gateway | Connection between the VPC and the internet |
| NAT Gateway | Outbound only internet access for private subnets |
| Security Group | Stateful firewall on the instance |
| Network ACL | Stateless firewall on the subnet |

```text
VPC              = the building
Subnet           = a floor
Route table      = the signboard
Internet Gateway = the main gate
NAT Gateway      = exit only door
Security Group   = guard at each room
Network ACL      = guard at each floor
```

### 05. DynamoDB & RDS - Database Services

AWS provides two different kinds of managed database. **DynamoDB** is a NoSQL database built for very high scale and fast key based access. **RDS** is a managed relational database that runs familiar SQL engines. In both cases AWS operates the underlying servers, applies patches, takes backups and handles failover.

```text
              DATABASES IN AWS
                     |
        ┌────────────┴────────────┐
        ↓                         ↓
    DynamoDB                     RDS
    NoSQL                        SQL
    key → item                   tables, rows, joins
    serverless                   managed database server
```

---

#### DynamoDB

#### NoSQL

DynamoDB is a key value and document database. Unlike a relational database it has no fixed schema and no joins. Items in the same table can have different attributes. Data is modelled around how the application reads it rather than normalised into many tables. In return DynamoDB delivers single digit millisecond latency at any scale, scales automatically, and requires no server management.

> DynamoDB = a serverless key value store that returns an item by its key in milliseconds at any scale.

#### Tables

A table is the only structural object in DynamoDB; there is no database above it. Each table has a name, a primary key, and a capacity mode:

| Mode | Billing | Suitable for |
| :--- | :--- | :--- |
| On demand | Per request | Unpredictable or spiky traffic |
| Provisioned | Fixed reads and writes per second | Steady, predictable traffic |

#### Items

An item is one record in a table, comparable to a row in SQL. It is stored as a JSON like document and can be up to 400 KB.

```json
{
  "user_id":  "u123",
  "order_id": "2024-06-01#001",
  "total":    49.99,
  "status":   "shipped"
}
```

#### Attributes

Attributes are the fields inside an item, such as `total` and `status` above. Apart from the key attributes, each item may have its own set of attributes. Adding a new attribute requires no schema change.

```text
Table     → the whole collection          (Orders)
Item      → one record                    (one order)
Attribute → one field inside the record   (total, status)
```

#### Partition key

The partition key is the required part of the primary key. DynamoDB hashes it to decide which physical partition stores the item. A good partition key has many distinct values so that data and traffic spread evenly.

```text
user_id  → millions of distinct values → even spread → good
country  → about 200 values → a few partitions get all the load → poor
```

If the table has only a partition key, the value must be unique for every item.

#### Sort key

The sort key is optional. Together with the partition key it forms a composite primary key, and the pair must be unique. Items sharing a partition key are stored together in sort key order, which makes range queries efficient.

| Partition key | Sort key | Query enabled |
| :--- | :--- | :--- |
| user_id | order_date | All orders of one user between two dates |
| device_id | timestamp | Readings of one device for the last hour |
| customer_id | record_type | Several record types for one customer in one table |

#### DynamoDB use cases

* Shopping carts and user sessions.
* Gaming leaderboards and player profiles.
* IoT and clickstream data with millions of writes per second.
* Serverless backends with Lambda and API Gateway.
* Any workload that needs fast lookup by key at very high scale.

---

#### RDS

#### Relational database

RDS (Relational Database Service) runs a managed SQL database. Data is stored in tables with defined columns, tables are linked by foreign keys, and SQL supports joins and transactions. AWS installs and patches the engine, takes backups and provides failover, while the application connects with the same drivers and tools used for a self hosted database.

```text
Customer responsibility          AWS responsibility
Schema design                    Install and patch the engine
SQL queries                      Automated backups
Application connection           Replace failed hardware
                                 Failover (Multi-AZ)
```

> RDS = a managed relational database server.

#### Supported engines

| Engine | Notes |
| :--- | :--- |
| MySQL | Most widely used open source engine |
| PostgreSQL | Feature rich, popular for new applications |
| MariaDB | Community fork of MySQL |
| Oracle | Enterprise, licence included or bring your own |
| Microsoft SQL Server | Windows based workloads |
| Amazon Aurora | AWS built engine compatible with MySQL and PostgreSQL, higher performance and automatic storage scaling |

#### DB instances

A DB instance is the database server itself. When creating one the following are chosen:

```text
Engine and version   → PostgreSQL 16
Instance class       → db.t3.micro (free tier) or db.r6g.large (memory optimised)
Storage              → 20 GB gp3 SSD
Network              → VPC and private subnets
```

The instance is reached through an endpoint such as `mydb.abc123.ap-south-1.rds.amazonaws.com` on the engine's port. There is no SSH access to the underlying server.

#### Security

| Measure | Purpose |
| :--- | :--- |
| Private subnet, no public IP | Database is not reachable from the internet |
| Security group allowing the DB port only from the application tier's security group | Only application servers can connect |
| Encryption at rest with KMS, enabled at creation | Data on disk is encrypted; cannot be enabled later without a snapshot restore |
| SSL/TLS enforced | Data in transit is encrypted |
| Credentials in Secrets Manager or IAM database authentication | No passwords in application code |

#### Backups

| Type | Behaviour |
| :--- | :--- |
| Automated backups | Daily snapshot plus transaction logs; restore to any second within the retention period of 1 to 35 days |
| Manual snapshots | Taken on demand, kept until deleted; recommended before major changes |

A restore always creates a new DB instance with a new endpoint. The existing instance is never overwritten.

#### Multi-AZ

Multi-AZ keeps a synchronous standby copy of the database in a second Availability Zone.

```text
Primary (AZ-a)  ══ synchronous replication ══►  Standby (AZ-b)

Primary fails
   ↓
AWS switches the same endpoint to the standby (about one minute)
   ↓
Application reconnects without configuration changes
```

Multi-AZ provides high availability. The standby cannot serve read traffic.

#### Read replicas

A read replica is an asynchronous copy of the database that applications can read from. Writes go to the primary only and are replicated to the replicas with a small delay. Several replicas can exist, including in other regions, and a replica can be promoted to a standalone database.

```text
Primary ── async ──► Replica 1  ◄── reporting queries
        ── async ──► Replica 2  ◄── analytics queries
```

| | Multi-AZ | Read replica |
| :--- | :--- | :--- |
| Purpose | Failover and availability | Scaling read traffic |
| Replication | Synchronous | Asynchronous |
| Readable by application | No | Yes |
| Location | Same region, different AZ | Same or different region |

#### RDS use cases

* Web and mobile application backends that require transactions.
* E-commerce orders, payments and inventory.
* Applications already built on MySQL or PostgreSQL.
* Reporting and business intelligence on relational data.

---

#### Choosing between DynamoDB and RDS

| Requirement | DynamoDB | RDS |
| :--- | :--- | :--- |
| Joins, transactions, complex SQL | No | Yes |
| Key lookups at very high scale | Yes | Possible but costly |
| Frequent schema changes | Easy | Requires migrations |
| Serverless, pay per request | Yes | Aurora Serverless only |
| Existing SQL application | No | Yes |

#### Summary

| Concept | Meaning |
| :--- | :--- |
| DynamoDB | Serverless NoSQL key value database |
| Table / Item / Attribute | Collection / record / field |
| Partition key | Required key that decides where an item is stored |
| Sort key | Optional key that orders items within a partition |
| RDS | Managed relational SQL database |
| DB instance | The database server, chosen by engine and size |
| Multi-AZ | Synchronous standby for failover |
| Read replica | Asynchronous copy for read scaling |

```text
DynamoDB      = locker with a key, instant, unlimited lockers
RDS           = filing cabinet with labelled drawers, maintained by AWS
Partition key = locker number
Sort key      = order inside the locker
Multi-AZ      = spare cabinet in another room
Read replica  = photocopy for people who only read
```
