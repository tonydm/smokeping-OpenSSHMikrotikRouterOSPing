# Smokeping - OpenSSHMikrotikRouterOSPing Probe

![Logo](https://github.com/tonydm/smokeping-OpenSSHMikrotikRouterOSPing/blob/master/screenshots/smokeping_logo.png)

Mikrotik RouterOS SSH Ping probe for Smokeping

This is a probe for Smokeping that connects to a Mikrotik RouterOS Device via SSH to source ping requests to monitor latency.

[SmokePing](https://oss.oetiker.ch/smokeping/), written by Tobias Oetiker and Niko Tyni, is a latency graphing and alerting system.  Smokeping is a valuable tool to monitor network performance metrics.
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

  #### For debugging
  - Data::Dumper;
  - Log::Log4perl
  
### Supports

- Source IP
- Preferred Source IP
- Interface Name
- Host IP or FQDN.  (FQDN if DNS is enabled on Mikrotik Router)
- Packet Size
- Target Ping Count (Default: 20, MAX: 50)
- Routing Table Name
- Time to Live
- DSCP ID
- Do Not Fragment flag
- Target Host SSH Port (Default: 22 or Non-Standard)
- User defined openssh-client path (/usr/bin/ssh)
- Multiplexed SSH Connections (Enabled by default)
  - User defined SSH Control Socket File Path (Default: ~/.libnet-openssh-perl)
  - User defined SSH Control Socket Persist Timeout (Default: 10 min)
- Separate Debug Output from Smokeping's debugging
  - Specify user defined output file and location

### Multiplexed SSH Connections

Multiplexing is the ability to send more than one signal over a single line or connection.  In OpenSSH (>=v3.9), multiplexing can re-use an existing outgoing TCP connection for multiple concurrent SSH sessions to a remote SSH server.  The benefit is avoiding the overhead of creating a new TCP connection (on both the local and remote hosts),  reauthenticating each time and faster connection time.  Reference: [https://en.wikibooks.org/wiki/OpenSSH/Cookbook/Multiplexing](https://en.wikibooks.org/wiki/OpenSSH/Cookbook/Multiplexing#:~:text=Multiplexing%20is%20the%20ability%20to,connection%20and%20reauthenticating%20each%20time)


## Setup

### Mikrotik Config

- Create a smokeping group with limited policy rights (ssh, read, test).  Then create a smokeping user with the smokeping group rights
  
  ![User](https://github.com/tonydm/smokeping-OpenSSHMikrotikRouterOSPing/blob/master/screenshots/winbox-users.png)
  
  ![User2](https://github.com/tonydm/smokeping-OpenSSHMikrotikRouterOSPing/blob/master/screenshots/winbox-users2.png)

- Ensure you have the SSH service enabled.
  
  ![Service1](https://github.com/tonydm/smokeping-OpenSSHMikrotikRouterOSPing/blob/master/screenshots/winbox-services-settings1.png)

- Set/Filter the allowed IPs either in the IP->Services or set up a Firewall rule to permit SSH connections per your security policy
  
  ![Service2](https://github.com/tonydm/smokeping-OpenSSHMikrotikRouterOSPing/blob/master/screenshots/winbox-services-settings2.png)

### Multiplexed SSH Connections

There are some requirements for this feature to work.  OpenSSH requires that the directory and it's parents, where the Master Control Socket File is created, must be writable only by the current effective user or root, otherwise the connection will be aborted to avoid insecure operation.  By default ~/.libnet-openssh-perl is used.

This probe will attempt to determine the $HOME directory of the user running/executing Smokeping, usually "smokeping" or "root".  In some cases, if using Docker or other container platform.  For example, the user could be "abc" in the case of using s6-supervise.  You can override this behaviour and specify the directory where the Master Control Socket File is created by setting the multiplex_socket_file_path option in the Probes config file.  You must ensure that the path meets the requirements as previously stated and that the permission masks be 0755 or more restrictive so that no other user can write to the dir/file.

  - The error you will see in the smokeping.log (smokeping debug and logging enabled) if you have defined your own socket file path w/o properly setting up permissions:

  - ```OpenSSHMikrotikRouterOSPing: OpenSSHMikrotikRouterOSPing connecting <source IP>: unable to establish master SSH connection: bad password or master process exited unexpectedly```

For each unique source (router) the probe will create a unique master control socket file.
#### Example of a user defined path (using Docker w/ s6-supervise)
##### Note: smokeping is run as user abc in this scenario

```
abc@5fef45006a04: mkdir /tmp/smokeping_ssh_sockets
abc@5fef45006a04: chown -R abc:users /tmp/smokeping_ssh_sockets
abc@5fef45006a04: chmod -R 0744 /tmp/smokeping_ssh_sockets
```

Example of two multiplexed control sockets created for two target hosts
```
abc@5fef45006a04:/$ ls -alF /tmp/smokeping_ssh_sockets/
total 8
drwxr--r-- 2 abc  users 4096 Oct 16 08:55  ./
drwxrwxrwt 1 root root  4096 Oct 16 08:47  ../
srw------- 1 abc  users    0 Oct 16 08:55 'control-smokeping@10.10.0.1'=
srw------- 1 abc  users    0 Oct 16 08:55 'control-smokeping@10.20.12.1'=

```

See https://metacpan.org/pod/Net::OpenSSH for full documentation


### Smokeping Config

- Copy the `OpenSSHMikrotikRouterOSPing.pm` file to the Smokeping probes directory on your server.  It can be located in a number of places depending on your distro.
  
   Common locations are:
  
  - Ubuntu: /usr/share/perl5/Smokeping/probes
  - Alpine docker: /usr/share/perl5/vendor_perl/Smokeping/probes
  - Or 'sudo find / -type f -name `Smokeping.pm`' to locate base directory

#### Probes file
```
+ OpenSSHMikrotikRouterOSPing

forks = 5
offset = 50%
step = 300
timeout = 60
packetsize = 56
pings = 20
# interface = <interface name> # Not used by default
# ttl = 20 # Not used by default
# dscp_id = <id number> # Not used by default
# rtable = <routing table name> # Not used by default
# do_not_fragment = false # Not used by default
routerospass = <userpass>
routerosuser = <username>
# ssh_binary_path = /usr/bin/ssh
multiplex_ssh = true
# multiplex_control_persist_time = 10 # Default is 10 min.  A value of 0 will leave socket file indefinitely
# multiplex_control_file_path = ~/.libnet-openssh-perl # Default
debug = false # Default
```

#### Targets file (Sample Configs)
```
# Config Examples

+ Edgerouter
# Define some defaults for this sections Targets 
probe = OpenSSHMikrotikRouterOSPing
title = Edge Router
menu = Edge Router
source = 172.20.0.1
psource = <WAN/Public Facing IP Address or other Internal Facing Interface>

++ nyc1_digitalocean_com
title = speedtest-nyc1.digitalocean.com (DigitalOcean New York 1)
host = speedtest-nyc1.digitalocean.com
# source - uses parent defined
# psource - uses parent defined
rtable = <routing table name>
# multiplex_ssh = true # Default
multiplex_control_file_path = <user defined path>
multiplex_control_persist_time = 0 # Indefinitely
debug = true

# More Config Examples

++ RemoteRouters
# Define some defaults for this sections Targets 
probe = OpenSSHMikrotikRouterOSPing
title = Remote Routers
menu = Remote Routers

++ remote_router1
title = Remote Router1
source = <remoterouter1_WAN_IP_Address>
# psource - No default defined, will use source address to source pings
host = <IP_of_interest>
ssh_port = 22431
debug = true

++ remote_router2
title = Remote Router2
source = <remoterouter2_WAN_IP_Address>
psource = <some_other_IP_address_on_remote_router>
host = <IP_of_interest>
rtable = <name_of_routing_table_other_than_main>
ssh_port = 29437
multiplex_ssh = false # Don't use multiplexed ssh connections - but why would you want to

++ remote_router3
title = Remote Router3
source = <remoterouter3_WAN_IP_Address>
host = <IP_of_interest>
interface = ether1-WAN
ttl = 20
dscp_id = 5
do_not_fragment = true
ssh_port = 29437
# multiplex_ssh = true # Default behaviour
multiplex_control_file_path = /tmp/smokeping_ssh_sockets # Override default ~/.libnet-openssh-perl
multiplex_control_persist_time = 20 # Override to use 20 minutes
```

### Manpage Documentation
```
# smokeping -man Smokeping::probes::OpenSSHMikrotikRouterOSPing

Supported probe-specific variables:

  forks
      Run this many concurrent processes at maximum

      Example value: 5

      Default value: 5

  offset
      If you run many probes concurrently you may want to prevent them
      from hitting your network all at the same time. Using the
      probe-specific offset parameter you can change the point in time
      when each probe will be run. Offset is specified in % of total
      interval, or alternatively as 'random', and the offset from the
      'General' section is used if nothing is specified here. Note that
      this does NOT influence the rrds itself, it is just a matter of when
      data acqusition is initiated. (This variable is only applicable if
      the variable 'concurrentprobes' is set in the 'General' section.)

      Example value: 50%

  packetsize
      The (optional) packetsize option lets you configure the packetsize
      for the pings sent. You cannot ping with packets larger than the MTU
      of the source interface, so the packet size should always be equal
      to or less than the MTU on the interface. MTU size can vary on each
      model of the Mikrotik RouterBoard. Reference your model for
      appropriate values if you wish to override.

      Default value: 56

  step
      Duration of the base interval that this probe should use, if
      different from the one specified in the 'Database' section. Note
      that the step in the RRD files is fixed when they are originally
      generated, and if you change the step parameter afterwards, you'll
      have to delete the old RRD files or somehow convert them. (This
      variable is only applicable if the variable 'concurrentprobes' is
      set in the 'General' section.)

      Example value: 300

  timeout
      How long a single 'ping' takes at maximum

      Example value: 15

      Default value: 5

  Supported target-specific variables:

  debug
      The (optional) debug option lets you configure probe or target specific
      debugging.

      Example value: true

      Default value: false

  debug_logfile
      The (optional) debug_logfile option lets you specify the debug
      logifile

      Example value: /tmp/my_debug.log

      Default value: /tmp/smokeping_debug.log

  do_not_fragment
      The (optional) do_not_fragment option lets you specify the
      do-not-fragment flag. If the flag is set packets will not be
      fragmented if size exceeds interface mtu.

      Example value: true

      Default value: false

  dscp_id
      The (optional) dscp_id option lets you specify the DSCP ID.

      Example value: 20

  interface
      The (optional) interface option lets you specify the name of the
      interface to source pings.

      Example value: ether1

  multiplex_ssh
      The (optional) multiplex_ssh option lets you specify whether to use
      multiplexed ssh connections, i.e. reuse the same SSH connection to a
      host. Default is enabled

      Example value: false

      Default value: true

  multiplex_control_socket_path
      The (optional) multiplex_control_socket_path ssh option lets you
      specify the master control socket path

      Example value: /tmp/smokeping_ssh_sockets

      Default value: ~/.libnet-openssh-perl

  multiplex_control_persist_time
      The (optional) multiplex_control_persist_time option lets you specify how
      long to persist the multiplex or Master Control Socket.  ControlMaster sockets
      are removed automatically when the master connection has ended. If
      multiplex_control_persist_time is set to 0, the master connection open
      will be left open in the background to accept new connections until killed
      explicitly or ends at a pre-defined timeout.  If multiplex_control_persist_time
      is set to a time, then it will leave the master connection open for the
      designated time or until the last multiplexed session is closed, whichever is longer.

      Example value: 0

      Default value: 10

  pings
      The (optional) pings option lets you specify the number of pings
      sent. A reasonable max value is 20. However, a max value of 50 is
      allowed.

      Example value: 20

      Default value: 20

  psource
      The (optional) psource option specifies an alternate IP address or
      Interface from which you wish to source your pings from. Mikrotik
      routers can have many many IP addresses, and interfaces. When you
      ping from a router you have the ability to choose which interface
      and/or which IP address the ping is sourced from. Specifying an
      IP/interface does not necessarily specify the interface from which
      the ping will leave, but will specify which address the packet(s)
      appear to come from. If this option is left out the Mikrotik
      RouterOS Device will source the packet automatically based on
      routing and/or metrics. If this doesn't make sense to you then just
      leave it out.

      Example value: 192.168.2.129

  routerospass
      The (manditory) routerospass option allows you to specify the SSH
      login password.

      Example value: password

      This setting is mandatory.

  routerosuser
      The (manditory) routerosuser option allows you to specify the SSH
      login username that has ping capability on the Mikrotik RouterOS
      Device.

      Example value: user

      This setting is mandatory.

  rtable
      The (optional) rtable option lets you specify the routing table to
      use in the ping command.

      Example value: secondary_route

  source
      The (manditory) source option specifies the Mikrotik RouterOS device
      that is going to run the ping commands. This address will be used
      for the ssh connection.

      Example value: 192.168.2.1

      This setting is mandatory.

  ssh_binary_path
      The (optional) ssh_binary_path option lets you specify the path for
      the ssh client binary. This option will specify the path to the
      Net::OpenSSH host connector. It may be necessary to define the path
      to the binary if it is not found in the $PATH.

      Example value: /usr/bin/ssh

      Default value: /usr/bin/ssh

  ssh_port
      The (optional) ssh_port option lets you specify a non standard SSH
      port.

      Example value: 22431

      Default value: 22

  ttl The (optional) ttl option lets you specify the Time to Live value
      for the pings sent. A reasonable max value is 20. However, a max
      value of 255 allowed.

      Example value: 20

      Default value: 20
```

### Bugs

- None reported

### TODO

- Add support 
  - SSH Key Authentication

### License

GNU GENERAL PUBLIC LICENSE v3.0

[https://www.gnu.org/licenses/gpl-3.0](https://www.gnu.org/licenses/gpl-3.0)
