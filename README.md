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
```unable to establish master SSH connection```
  
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
- Specify Routing Table
- Target Host SSH Port (Default: 22)
- User defined openssh-client path (/usr/bin/ssh)
- Multiplexed SSH Connections (Enabled by default)
  - User defined SSH Control Socket File Path (Default: ~/.libnet-openssh-perl)
  - User defined SSH Control Socket Persist Timeout (Default: 10 min)


### Multiplexed SSH Connections

Multiplexing is the ability to send more than one signal over a single line or connection. In OpenSSH (>=v3.9), multiplexing can re-use an existing outgoing TCP connection for multiple concurrent SSH sessions to a remote SSH server, avoiding the overhead of creating a new TCP connection (on both the local and remote hosts) and reauthenticating each time.  Reference: [https://en.wikibooks.org/wiki/OpenSSH/Cookbook/Multiplexing](https://en.wikibooks.org/wiki/OpenSSH/Cookbook/Multiplexing#:~:text=Multiplexing%20is%20the%20ability%20to,connection%20and%20reauthenticating%20each%20time)

There are some requirements for this feature to work.  OpenSSH requires that the directory and it's parents, where the Master Control Socket File is created, must be writable only by the current effective user or root, otherwise the connection will be aborted to avoid insecure operation.  By default ~/.libnet-openssh-perl is used.

This probe will attempt to determine the $HOME directory of the user running/executing Smokeping, usually "smokeping" or "root".  In some cases, if using Docker or other container platform, the user could be "abc" in the case of using s6-supervise for example.  You can override this behaviour and specify the directory where the Master Control Socket File is created by setting the multiplex_socket_file_path option in the Probes config file.  You must ensure that the path meets the requirements as previously stated and that the permission masks be 0755 or more restrictive so that no other user can write to the dir/file.

  - The error you will see in the smokeping.log (if enabled) if you have defined your own socket file path w/o properly setting up permissions:

  - ```OpenSSHMikrotikRouterOSPing: OpenSSHMikrotikRouterOSPing connecting 10.10.0.1: unable to establish master SSH connection: bad password or master process exited unexpectedly```


For each unique source (router) the probe will create a unique master control socket file.


#### Example of a user defined path (using Docker w/ s6-supervise)
##### Note: smokeping is run as user abc in this scenario

```
abc@5fef45006a04: mkdir /tmp/smokeping_ssh_sockets
abc@5fef45006a04: chown -R abc:users /tmp/smokeping_ssh_sockets
abc@5fef45006a04: chmod -R 0744 /tmp/smokeping_ssh_sockets
```

Two multiplexed control sockets have been created for two target hosts
```
abc@5fef45006a04:/$ ls -alF /tmp/smokeping_ssh_sockets/
total 8
drwxr--r-- 2 abc  users 4096 Oct 16 08:55  ./
drwxrwxrwt 1 root root  4096 Oct 16 08:47  ../
srw------- 1 abc  users    0 Oct 16 08:55 'control-smokeping@10.10.0.1'=
srw------- 1 abc  users    0 Oct 16 08:55 'control-smokeping@10.20.12.1'=

```

See https://metacpan.org/pod/Net::OpenSSH for full documentation


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

#### 

#### Probes

###### /etc/smokeping/config.d/probes

```
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
multiplex_ssh = 1
multiplex_control_persist_time = 10
multiplex_control_file_path = <user defined path>
rtable = <routing table name>
```

** Note: Use "which ssh" to determine the ssh binary path

### Targets (Sample Configs)

###### /etc/smokeping/config.d/Targets

```
# Config Examples

+ Edgerouter
# Define some defaults for this sections Targets 
probe = OpenSSHMikrotikRouterOSPing
title = Edge Router
menu = Edge Router
source = 172.20.0.1
psource = <WAN/Public Facing IP Address or other Internal Facing Interface or IP Gateway>

++ nyc1_digitalocean_com
title = speedtest-nyc1.digitalocean.com (DigitalOcean New York 1)
host = speedtest-nyc1.digitalocean.com
# source - uses parent defined
# psource - uses parent defined
# multiplex_ssh = 1 # Default
# multiplex_control_file_path = ~/.libnet-openssh-perl # Default
# multiplex_control_persist_time = 10 # Default


# More Config Examples

++ RemoteRouters
# Define some defaults for this sections Targets 
probe = OpenSSHMikrotikRouterOSPing
title = Remote Routers
menu = Remote Routers

++ remote_router1
title = Remote Router1
source = remoterouter1_WAN_IP_Address
# psource - No default defined, will use source address to source pings
host = IP_of_interest
ssh_port = 22431

++ remote_router2
title = Remote Router2
source = remoterouter2_WAN_IP_Address
psource = some_other_IP_address_on_remote_router
host = IP_of_interest
ssh_port = 29437
multiplex_ssh = 0 # Don't use multiplexed ssh connections - but why would you want to

++ remote_router3
title = Remote Router3
source = remoterouter3_WAN_IP_Address
host = IP_of_interest
ssh_port = 29437
# multiplex_ssh = 1 # Default behaviour
multiplex_control_file_path = /tmp/smokeping_ssh_sockets # Override default ~/.libnet-openssh-perl
multiplex_control_persist_time = 20 # Override to use 20 minutes
rtable = name_of_routing_table_other_than_main

```

### Bugs

- None reported

### TODO

- Add support 
  - SSH Key Authentication
  - Specify Interface Name
  - Specify DSCP
  - Specify TTL

### License

GNU GENERAL PUBLIC LICENSE v3.0

[https://www.gnu.org/licenses/gpl-3.0](https://www.gnu.org/licenses/gpl-3.0)
