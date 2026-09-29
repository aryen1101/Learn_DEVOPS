# 02. EC2 - Compute

EC2 (Elastic Compute Cloud) is a virtual server in AWS. I pick the operating system, the size, the disk and the network, and within a minute I have a machine I can SSH into. I pay only for the time it is running. Most other things in AWS are built on top of EC2 in some way.

**AMI.** An Amazon Machine Image is the template the server starts from. It holds the operating system and any software that was pre installed, for example Amazon Linux 2023 or Ubuntu 24.04. I can also make my own AMI from a running instance, so if I set up a web server once I can launch ten identical copies from it.

**Instance types.** The instance type decides how much CPU, memory, storage and network the server gets. The name tells the story: in `t3.micro`, `t` is the family, `3` is the generation and `micro` is the size. The t family is small and cheap (free tier), c is for CPU heavy work, r is for memory heavy work like databases, and g or p have GPUs for machine learning.

**Key pairs.** A key pair is how I log in to a Linux instance over SSH. AWS keeps the public key and I download the private `.pem` file once when I create it. If I lose that file I cannot log in to the instance any more, so it has to be kept safe.

**Security Groups.** A security group is the firewall around the instance. It has inbound rules for what can come in and outbound rules for what can go out. By default everything inbound is blocked and everything outbound is allowed. For a web server I would open port 22 only from my IP and ports 80 and 443 from anywhere. It is stateful, so if a request is allowed in, the reply is allowed out automatically.

**EBS.** Elastic Block Store is the hard disk of the instance. The root volume holds the OS and I can attach more volumes for data. EBS lives separately from the instance, so stopping the instance keeps the data, and I can take snapshots as backups. The usual type is `gp3` SSD.

**Public vs private IP.** Every instance gets a private IP inside the VPC that stays the same for its whole life and is used by other servers in the same VPC. A public IP is only given if the subnet is public and the option is on, and it changes every time the instance stops and starts. An Elastic IP is a public IP I reserve so it never changes. A database server should only have a private IP.

**Instance lifecycle.** An instance goes pending, then running. From running I can stop it, which keeps the disk and stops the compute bill, or terminate it, which deletes it for good. A reboot is like restarting a laptop, the IP and data stay. Stopping a dev machine at night is an easy way to save money.

**Common use cases.** Hosting a website or API, running a Jenkins or GitHub Actions runner, a bastion host to reach private servers, batch jobs and data processing, Kubernetes worker nodes, and test machines that are started when needed.
