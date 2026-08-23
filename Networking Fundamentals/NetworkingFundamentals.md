# Networking Fundamentals

## 1. What is an IP address?

IP stands for **Internet Protocol**. An IP address identifies a network interface so that devices can send data to it. An IP address does not always identify a person or a single physical device; one device can have multiple addresses, and several devices can share one public address through NAT.

Common commands for viewing IP addresses on Linux:

```bash
ip address
ip addr
ip a
hostname -I
```

`ip address` is the modern command. `ifconfig` is older and may not be installed by default.

## 2. Network ID and host ID

An IP address is divided into a **network portion** and a **host portion**. The subnet mask or CIDR prefix tells us where the division is. The network portion identifies the network, while the host portion identifies an interface within that network.

Example:

```text
IP address:  192.168.1.10
Subnet mask: 255.255.255.0 (/24)
Network:     192.168.1.0
Host part:   10
```

The host part is not always just the last number. Its size depends on the subnet mask.

## 3. IPv4 address classes (historical)

IPv4 addresses were traditionally divided into classes. This system is now largely obsolete for network allocation because modern networks use **CIDR**. It is still useful for understanding older networking material.

| Class | First octet | Default mask | Traditional use |
| --- | --- | --- | --- |
| A | 1-126 | 255.0.0.0 (`/8`) | Very large networks |
| B | 128-191 | 255.255.0.0 (`/16`) | Medium-sized networks |
| C | 192-223 | 255.255.255.0 (`/24`) | Small networks |
| D | 224-239 | Not applicable | Multicast |
| E | 240-255 | Reserved | Experimental/reserved |

`0.x.x.x` is reserved, and `127.0.0.0/8` is used for loopback addresses such as `127.0.0.1`. Class A, B, and C labels do not determine the actual network/host division in a modern network.

## 4. Subnet masks and CIDR

A subnet mask divides an IPv4 address into network and host portions. A `1` bit in the mask represents the network portion, and a `0` bit represents the host portion.

**CIDR** means **Classless Inter-Domain Routing**. It writes the number of network bits after a slash:

```text
192.168.1.10/24
```

Here, the first 24 bits are network bits and the remaining 8 bits are host bits. The `/24` mask is `255.255.255.0`.

### Network and broadcast addresses

For a normal IPv4 subnet:

- The **network address** identifies the subnet. It is found by performing a bitwise AND between the IP address and subnet mask.
- The **broadcast address** sends traffic to all hosts in that subnet. It is found by setting all host bits to `1`.
- The first and last addresses are generally reserved for the network and broadcast addresses, so they are not normally assigned to hosts.

For `192.168.1.10/24`:

```text
Network address:   192.168.1.0
Usable host range:  192.168.1.1 - 192.168.1.254
Broadcast address:  192.168.1.255
```

Some special subnet types, such as `/31` and `/32`, have different rules.

### Changing an IP address on Linux

The interface name and prefix length are required. This temporary change may be lost after a restart:

```bash
sudo ip address add 192.168.1.50/24 dev eth0
```

Replace `eth0` with the actual interface name, such as `ens33` or `enp0s3`. Use a persistent network configuration method for a permanent change.

## 5. Public and private IP addresses

### Public IP address

A public IP address is globally unique and used for communication across the Internet. It is usually assigned by an Internet service provider. A public address is not automatically reachable from the Internet; firewalls, routing, and NAT rules also matter.

Examples include `8.8.8.8` and `1.1.1.1`.

### Private IP address

A private IP address is used inside a local network (LAN). Private addresses are not routed directly across the public Internet and can be reused by different organizations.

Private IPv4 ranges are:

```text
10.0.0.0/8
172.16.0.0/12
192.168.0.0/16
```

Private addresses are commonly assigned by a router or DHCP server. NAT often allows multiple private devices to use one public IP address.

## 6. Important protocols

### TCP and UDP

| Feature | TCP | UDP |
| --- | --- | --- |
| Full form | Transmission Control Protocol | User Datagram Protocol |
| Connection | Connection-oriented | Connectionless |
| Reliability | Reliable delivery | No built-in delivery guarantee |
| Ordering | Maintains order | No built-in ordering |
| Acknowledgements | Yes | No |
| Retransmission | Yes | No |
| Flow and congestion control | Yes | No built-in control |
| Header size | 20-60 bytes | 8 bytes |
| Typical benefit | Reliability | Low overhead and low latency |

TCP establishes a connection using a three-way handshake:

```text
Client -> SYN
Server -> SYN + ACK
Client -> ACK
```

TCP numbers data, acknowledges received data, and retransmits missing data. It is commonly used by HTTP/HTTPS, SSH, FTP, and many email protocols.

UDP does not establish a connection or guarantee delivery. It is useful when speed and low delay are more important than retransmission, such as DNS queries, DHCP, VoIP, online games, and some streaming protocols.

### ICMP

ICMP stands for **Internet Control Message Protocol**. It is used for network error messages and diagnostics. The traditional `ping` command normally uses ICMP Echo Request and Echo Reply messages. ICMP is commonly associated with the network layer.

### DNS and DHCP

- **DNS** translates names such as `example.com` into IP addresses. It commonly uses UDP port 53, and TCP port 53 is also used in some cases.
- **DHCP** automatically provides devices with an IP address and other network settings. It uses UDP ports 67 (server) and 68 (client).

## 7. OSI model

The OSI model is a way to understand how networking responsibilities are grouped. Real protocols do not always fit perfectly into only one layer.

| Layer | Name | Examples |
| --- | --- | --- |
| 7 | Application | HTTP, HTTPS, DNS, DHCP, FTP, SMTP, IMAP, SSH |
| 6 | Presentation | Encryption, encoding, data formats; TLS is often discussed here |
| 5 | Session | Session management and RPC-related functions |
| 4 | Transport | TCP, UDP |
| 3 | Network | IP, ICMP |
| 2 | Data Link | Ethernet, Wi-Fi, PPP, ARP* |
| 1 | Physical | Cables, fiber, radio signals |

`*` ARP maps an IPv4 address to a MAC address on a local network. It is commonly placed at Layer 2, although it sits between the network and data-link layers in practice.

## 8. Common ports

| Service | Port | Typical protocol |
| --- | --- | --- |
| SSH | 22 | TCP |
| HTTP | 80 | TCP |
| HTTPS | 443 | TCP (and sometimes UDP with HTTP/3) |
| DNS | 53 | UDP/TCP |
| DHCP | 67/68 | UDP |
| SMTP | 25, 465, 587 | TCP |
| MySQL | 3306 | TCP |

A web application is commonly exposed to users on port **80** for HTTP or **443** for HTTPS. The application may run internally on another port, with a web server or reverse proxy forwarding traffic to it.

## 9. Useful Linux commands

```bash
hostname                   # Show the system hostname
whoami                     # Show the current username
ip a                       # Show interfaces and IP addresses
ip route                   # Show the routing table
ping -c 4 8.8.8.8          # Send four ping requests
nslookup example.com       # Query DNS
curl https://example.com   # Make an HTTP/HTTPS request
curl -I https://example.com # Show response headers only
ss -tuln                   # Show listening TCP/UDP sockets numerically
tracepath example.com      # Show path, delay, and path MTU
traceroute example.com     # Show the route to a destination
```

The routing table acts like a map that tells the system where to send packets. `tracepath` and `traceroute` may not show every hop because routers or firewalls can block diagnostic responses.

`cat /etc/hosts` displays the local static hostname-to-IP mappings. It does not show all host details or all devices on the network.

### Telnet

Telnet can test whether a TCP port accepts a connection:

```bash
telnet example.com 80
```

Telnet sends data without encryption, so it should not be used for secure remote login. For port testing, `nc` (netcat) is often a better choice:

```bash
nc -vz example.com 80
```

## 10. Further reading

- https://github.com/Nency-Ravaliya/Networking
- https://github.com/Nency-Ravaliya/IP-quest
- https://github.com/Nency-Ravaliya/IPFIX-NETFLOW-NTP
- https://github.com/Nency-Ravaliya/How-DHCP-Works
- https://github.com/Nency-Ravaliya/Subnetting
