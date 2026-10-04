# 04. VPC - Networking

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
