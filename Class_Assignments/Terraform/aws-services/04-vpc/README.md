# 04. VPC - Networking

A VPC (Virtual Private Cloud) is my own private network inside AWS. Everything I launch, like EC2 instances and RDS databases, sits inside a VPC. I decide the IP range, how it is split into subnets, what can reach the internet and what stays hidden. Every account gets a default VPC so things work out of the box, but for real projects I create my own with public subnets for things the internet must reach and private subnets for everything else.

**CIDR.** CIDR is how the IP range is written. `10.0.0.0/16` means the first 16 bits are fixed and the rest are free, which gives 65,536 addresses. A `/24` gives 256. AWS reserves 5 addresses in every subnet, so a `/24` really has 251 usable. I use the private ranges like `10.0.0.0/8` and pick one that does not overlap with other networks I may connect later.

**Subnets.** A subnet is a slice of the VPC range that lives in one Availability Zone. It cannot stretch across zones. For high availability I create at least two subnets of each type in two zones. A subnet is only called public or private because of where its route table points.

**Route tables.** A route table is the list of rules that says where traffic goes based on its destination. Every subnet is attached to exactly one. The `local` route is always there and lets everything inside the VPC talk to each other. A public route table sends `0.0.0.0/0` to the Internet Gateway, a private one sends it to a NAT Gateway or nowhere.

**Internet Gateway.** The Internet Gateway is the door between the VPC and the internet. There is one per VPC. For a server to be reachable from outside it needs three things: a route to the IGW, a public IP, and a security group that allows the traffic.

**NAT Gateway.** A NAT Gateway lets servers in a private subnet reach the internet, for updates or API calls, while nobody on the internet can start a connection to them. It sits in a public subnet with an Elastic IP. It costs per hour and per GB, so small labs often skip it.

**Security Groups.** A security group is a firewall on the instance. It only has Allow rules and it is stateful. Rules can point at other security groups, for example allow port 3306 only from the web servers' group. This is the main way I control traffic between servers.

**Network ACLs.** A Network ACL is a firewall on the subnet. Unlike a security group it has both Allow and Deny rules, it is stateless so both directions need rules, and rules are checked in number order with the first match winning. Most of the time the default NACL is left alone. It is handy for blocking one bad IP from a whole subnet.

**Public vs private subnet.** A public subnet routes `0.0.0.0/0` to the Internet Gateway and its instances get public IPs, so it is where load balancers, bastion hosts and NAT Gateways go. A private subnet routes to a NAT or nothing, its instances have only private IPs, and it is where app servers, databases and caches go. Only things that must be reached from the internet belong in the public subnet.
