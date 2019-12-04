# Smokeping - OpenSSHMikrotikRouterOSPing Probe

![Logo](https://github.com/tonydm/smokeping-OpenSSHMikrotikRouterOSPing/blob/master/screenshots/smokeping_logo.png)

Mikrotik RouterOS SSH Ping probe for Smokeping

This is a probe for Smokeping that connects to a Mikrotik RouterOS Device via SSH to source ping requests to monitor latency.

[SmokePing](https://oss.oetiker.ch/smokeping/) is a latency logging and graphing and alerting system.  Smokeping is a valuable tool to monitor network performance metrics.
Also checkout the ([Github Repo](https://github.com/oetiker/SmokePing))

Where routers/switches are placed around a network's logical topology, one can set up SmokePing to monitor not only the latency between the local end and remote end (i.e. a local server to a remote server), but sourcing those pings from anywhere on your network from any vlan, network, or interface on the router can give insight into latency on any given segment of a network.  Placing/sourcing a ping from your networks edge can eliminate internal metrics and isolate upstream metrics.  This can, of course, be accomplished with Cisco, Juniper, Dell, Huawei, ZTE, and others.

### Background

Smokeping provides a number of [Probes](https://oss.oetiker.ch/smokeping/probe/index.en.html) to connect to a router or switch in order to source ping requests to gather latency metrics from the remote device.  However, only two probes provided by the Smokeping project provides SSH connectity and only to Arista and Juniper devices.  Smokeping also provides the TelnetIOSPing probe for Cisco devices.

I wanted a probe to connect to Mikrotik RouterOS devices via SSH. So I created this probe to provide that functionality.

![Target](https://github.com/tonydm/smokeping-OpenSSHMikrotikRouterOSPing/blob/master/screenshots/smokeping-target-graph.png)

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
![GitHub All Releases](https://img.shields.io/github/downloads/tonydm/smokeping-OpenSSHMikrotikRouterOSPing/total)
[![GitHub forks](https://img.shields.io/github/forks/tonydm/smokeping-OpenSSHMikrotikRouterOSPing)](https://github.com/tonydm/smokeping-OpenSSHMikrotikRouterOSPing/network)
[![GitHub stars](https://img.shields.io/github/stars/tonydm/smokeping-OpenSSHMikrotikRouterOSPing)](https://github.com/tonydm/smokeping-OpenSSHMikrotikRouterOSPing/stargazers)
[![GitHub issues](https://img.shields.io/github/issues/tonydm/smokeping-OpenSSHMikrotikRouterOSPing)](https://github.com/tonydm/smokeping-OpenSSHMikrotikRouterOSPing/issues)


### Requirements
 - Net::OpenSSH
 - IO::Pty

 ** Your OS may require that you install the openssh-client if you are seeing any of the following errors:
   - ```SSH connection failed: unable to establish master SSH connection: bad password or master process exited unexpectedly at```
   -  ```unable to establish master SSH connection```

 This is because the version of the Net::OpenSSH Perl module installed on your distro does not provide the multiplexing functionality required

  According to Net::OpenSSH [documentation](https://metacpan.org/pod/Net::OpenSSH#Solaris-(and-AIX-and-probably-others)):

   - To install the needed support
     - Alpine dist - run: apk add openssh-client
     - debian dist - run: [sudo] apt install openssh-client

### Supports
 - Source IP
 - Host (dest) IP or FQDN.  (FQDN if DNS is enabled on Mikrotik Router)
 - Packet Size (Default: 56)
 - Target Ping Count (Default: 20, MAX: 50)
 - Target SSH Port (Default: 22)
 - User defined openssh-client path (/usr/bin/ssh)

## Setup

### Mikrotik Config
 - Create a smokeping group with limited policy rights (ssh, read, test).  Then create a smokeping user with the smokeping group rights

 ![User](https://github.com/tonydm/smokeping-OpenSSHMikrotikRouterOSPing/blob/master/screenshots/winbox-users.png)

  ![User2](https://github.com/tonydm/smokeping-OpenSSHMikrotikRouterOSPing/blob/master/screenshots/winbox-users2.png)

 - Ensure you have the SSH service enabled.

 ![Service1](https://github.com/tonydm/smokeping-OpenSSHMikrotikRouterOSPing/blob/master/screenshots/winbox-services-settings1.png)

 - Set/Filter the allowed IPs either in the IP->Services or set up a Firewall rule to permit SSH connections per your security policy

 ![Service2](https://github.com/tonydm/smokeping-OpenSSHMikrotikRouterOSPing/blob/master/screenshots/winbox-services-settings2.png)

### Smokeping Config
 - Copy the OpenSSHMikrotikRouterOSPing.pm file to the Smokeping probes directory on your server.  It can be located in a number of places depending on your distro.

    Common locations are:
    - Ubuntu: /usr/share/perl5/Smokeping/probes
    - Alpine docker: /usr/share/perl5/vendor_perl/Smokeping/probes
    - Or 'sudo find / -type f -name Smokeping.pm' to locate


#### Probes

###### /etc/smokeping/config.d/probes
````
+ OpenSSHMikrotikRouterOSPing

forks = 5
offset = 50%
packetsize = 56
step = 300
timeout = 60
pings = 20
routerospass = <userpass>
routerosuser = <username>
ssh_binary_path = /usr/bin/ssh
````
** Note: Use "which ssh" to determine the ssh binary path

### Targets
###### /etc/smokeping/config.d/Targets

  ````
+ Edgerouter

title = Edge Router
menu = Edge Router
probe = OpenSSHMikrotikRouterOSPing
source = 172.20.0.1
psource = <WAN/Public Facing IP Address>

++ nyc1_digitalocean_com
host = speedtest-nyc1.digitalocean.com
title = speedtest-nyc1.digitalocean.com (DigitalOcean New York 1)

++ my_remote_server.com
host = my_remote_server
title = My Remote Server
ssh_port = 22431
  ````

### Bugs
  - None reported

### License

GNU GENERAL PUBLIC LICENSE v3.0

[https://www.gnu.org/licenses/gpl-3.0](https://www.gnu.org/licenses/gpl-3.0)
