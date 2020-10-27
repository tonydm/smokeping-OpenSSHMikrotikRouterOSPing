## Manpage
### \#smokeping -man Smokeping::probes::OpenSSHMikrotikRouterOSPing

```
NAME
    Smokeping::probes::OpenSSHMikrotikRouterOSPing - Mikrotik RouterOS SSH
    Probe for SmokePing

SYNOPSIS
     *** Probes ***

     +OpenSSHMikrotikRouterOSPing

     forks = 5
     offset = 50%
     packetsize = 56
     step = 300
     timeout = 15

     # The following variables can be overridden in each target section
     debug = true
     debug_logfile = /tmp/my_debug.log or /tmp/smokeping_target1.log
     do_not_fragment = true
     dscp_id = 20
     interface = ether1
     multiplex_control_persist_time = 10
     multiplex_control_socket_path = /tmp/smokeping_ssh_sockets
     multiplex_ssh = false
     pings = 20
     psource = 192.168.2.129
     routerospass = password # mandatory
     routerosuser = user # mandatory
     rtable = secondary_route
     source = 192.168.2.1 # mandatory
     ssh_binary_path = /usr/bin/ssh
     ssh_port = 22431
     ttl = 20

     # [...]

     *** Targets ***

     probe = OpenSSHMikrotikRouterOSPing # if this should be the default probe

     # [...]

     + mytarget
     # probe = OpenSSHMikrotikRouterOSPing # if the default probe is something else
     host = my.host
     debug = true
     debug_logfile = /tmp/my_debug.log or /tmp/smokeping_target1.log
     do_not_fragment = true
     dscp_id = 20
     interface = ether1
     multiplex_control_persist_time = 10
     multiplex_control_socket_path = /tmp/smokeping_ssh_sockets
     multiplex_ssh = false
     pings = 20
     psource = 192.168.2.129
     routerospass = password # mandatory
     routerosuser = user # mandatory
     rtable = secondary_route
     source = 192.168.2.1 # mandatory
     ssh_binary_path = /usr/bin/ssh
     ssh_port = 22431
     ttl = 20

DESCRIPTION
    Connect to Mikrotik RouterOS Device via OpenSSH to run ping commands.
    This probe uses the "ping" cli of the Mikrotik RouterOS. You have
    options to specify which interface the ping is sourced from, which
    routing table to use and multiplexd ssh connections, as well as others.

VARIABLES
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
        The (optional) debug option lets you configure probe or target
        specific debugging.

        Example value: true

        Default value: false

    debug_logfile
        The (optional) debug_logfile option lets you specify the debug
        logifile

        Example value: /tmp/my_debug.log or /tmp/smokeping_target1.log

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

    multiplex_control_persist_time
        The (optional) multiplex_control_persist_time option lets you
        specify, in minutes, how long to persist the multiplex or Master
        Control Socket. ControlMaster sockets are removed automatically when
        the master connection has ended. If multiplex_control_persist_time
        is set to 0, the master connection open will be left open in the
        background to accept new connections until killed explicitly or ends
        at a pre-defined timeout. If multiplex_control_persist_time is set
        to a time, then it will leave the master connection open for the
        designated time or until the last multiplexed session is closed,
        whichever is longer.

        Example value: 20

        Default value: 10

    multiplex_control_socket_path
        The (optional) multiplex_control_socket_path ssh option lets you
        specify the master control socket path

        Example value: /tmp/smokeping_ssh_sockets

        Default value: ~/.libnet-openssh-perl

    multiplex_ssh
        The (optional) multiplex_ssh option lets you specify whether to use
        multiplexed ssh connections, i.e. reuse the same SSH connection to a
        host.

        Example value: false

        Default value: true

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
        for the pings sent. Default is 64.

        Example value: 20

AUTHORS
    Tony DeMatteis <tonydema@gmail.com>

    based on Smokeping::Probes::OpenSSHJunOSPing by Tobias Oetiker
    <tobi@oetiker.ch>, which itself is based on
    Smokeping::probes::TelnetJunOSPing by S H A N <shanali@yahoo.com>.

    Additional Credits: Routing Table option - https://github.com/leostereo
    Leandro needed to be able to specify a specific routing table. Leandro
    contribuited code suggestions to enable this functionality

NOTES
  Mikrotik RouterOS configuration
    The Mikrotik RouterOS device should have a username/password configured,
    and the ssh server must not be disabled. You can use a non standard
    port.

    Make sure to connect to the remote host once from the command line as
    the user who is running smokeping. On the first connect ssh will ask to
    add the new host to its known_hosts file. This will not happen
    automatically so the script will fail to login until the ssh key of your
    Mikrotik RouterOS device is in the known_hosts file.

  Requirements
    This module requires the Net::OpenSSH and IO::Pty perl modules
```