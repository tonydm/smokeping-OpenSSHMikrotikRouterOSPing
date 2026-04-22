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
     routerospass = password # optional - see Authentication notes
     routerosuser = user # mandatory
     rtable = secondary_route
     source = 192.168.2.1 # mandatory
     ssh_binary_path = /usr/bin/ssh
     ssh_key_path = /etc/smokeping/id_ed25519
     ssh_connect_timeout = 10
     ssh_port = 22431
     ssh_strict_host_key_checking = accept-new
     ssh_timeout = 60
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
     routerospass = password # optional - see Authentication notes
     routerosuser = user # mandatory
     rtable = secondary_route
     source = 192.168.2.1 # mandatory
     ssh_binary_path = /usr/bin/ssh
     ssh_key_path = /etc/smokeping/id_ed25519
     ssh_connect_timeout = 10
     ssh_port = 22431
     ssh_strict_host_key_checking = accept-new
     ssh_timeout = 60
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
        specific debugging. When enabled the log includes a cycle-start
        configuration snapshot, the composed ssh command, phase timings
        (connect/command/parse), and the RouterOS packet-loss summary
        cross-checked against the parsed samples.

        Security warning: with debug enabled the log also contains a
        Data::Dumper dump of the Net::OpenSSH options hash, which
        includes routerospass in plaintext when password auth is in use,
        and the full on-disk path of ssh_key_path when key auth is in
        use. Ensure debug_logfile lives on a filesystem readable only by
        the smokeping user, and redact the file before sharing it
        externally (support tickets, public issue trackers, pastebins,
        etc.).

        Example value: true

        Default value: false

    debug_logfile
        The (optional) debug_logfile option lets you specify the debug
        logifile.

        With debug=true this file contains sensitive material including
        the target's routerospass (when password auth is used) and the
        on-disk path of ssh_key_path. Treat it as secret: lock it down
        with filesystem permissions readable only by the smokeping user,
        and rotate/redact it before sharing externally.

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
        The (optional) routerospass option specifies the SSH login
        password. Required unless ssh_key_path is set, or ssh-agent / a
        default identity file (e.g. ~/.ssh/id_ed25519) is configured for
        the user running smokeping. See the Authentication section in the
        notes.

        Note: when debug=true the value of routerospass is written to
        debug_logfile in plaintext as part of the Net::OpenSSH options
        dump. See the debug option for details and mitigation.

        Example value: password

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

    ssh_key_path
        The (optional) ssh_key_path option specifies the path to a private
        key file used to authenticate to the Mikrotik RouterOS device. When
        set the ssh client is invoked with -i <path>, bypassing
        routerospass. The key must be readable only by the user running
        smokeping (typically mode 0600) or the ssh client will refuse to
        use it. See the Authentication section in the notes for the three
        supported modes (password, key file, ssh-agent / default identity
        files).

        Example value: /etc/smokeping/id_ed25519

    ssh_connect_timeout
        The (optional) ssh_connect_timeout option bounds the TCP/SSH
        handshake in seconds via OpenSSH's ConnectTimeout option. This is
        the main knob for failing fast when the Mikrotik RouterOS device is
        unreachable, so probe cycles do not blow out waiting the full
        ssh_timeout. Must be less than ssh_timeout.

        Example value: 10

        Default value: 10

    ssh_port
        The (optional) ssh_port option lets you specify a non standard SSH
        port.

        Example value: 22431

        Default value: 22

    ssh_strict_host_key_checking
        The (optional) ssh_strict_host_key_checking option controls
        OpenSSH's StrictHostKeyChecking policy for the ssh connection to
        the Mikrotik RouterOS device. Valid values: 'accept-new' (default
        - auto-adds new host keys to known_hosts on first connect, rejects
        changed keys), 'no' (silently trust any host key), 'yes' (require
        key to already be in known_hosts, fail otherwise).

        Example value: accept-new

        Default value: accept-new

    ssh_timeout
        The (optional) ssh_timeout option specifies, in seconds, the
        Net::OpenSSH master-channel timeout. This bounds the overall
        duration of the ssh session including the running ping command, so
        it must be larger than the ping command duration (roughly pings *
        1s + headroom). For short TCP handshake timeouts see
        ssh_connect_timeout. This must be lower than 'step'.

        Example value: 60

        Default value: 60

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
    The Mikrotik RouterOS device should have a username configured, and the
    ssh server must not be disabled. You can use a non standard port. The
    user needs either a password set or an ssh public key associated with
    it via /user ssh-keys import on the router.

  Authentication
    The probe supports three ways to authenticate to the Mikrotik RouterOS
    device. Pick one per target.

    *   Password: set routerospass. Leave ssh_key_path unset. This is the
        legacy default.

    *   SSH key file: set ssh_key_path to the path of a private key file
        readable by the user running smokeping. When ssh_key_path is set
        it takes precedence over any routerospass inherited from the
        probe-level default, so you can flip individual targets to key
        auth without having to unset routerospass on the parent. Install
        the matching public key on the router with /user ssh-keys import
        public-key-file=<file> user=<routerosuser>. The README has a
        step-by-step walk-through.

    *   ssh-agent or system default identity: leave both routerospass and
        ssh_key_path unset. Net::OpenSSH will invoke the system ssh client
        which picks up SSH_AUTH_SOCK, ~/.ssh/id_ed25519, ~/.ssh/id_rsa
        etc as it would for an interactive login. This is useful for
        containerised smokeping deployments that mount an agent socket.

    If none of the three are configured the connection will fail at
    runtime with a Net::OpenSSH authentication error logged to the
    smokeping log.

    By default (ssh_strict_host_key_checking=accept-new) the probe will add
    the router's host key to the smokeping user's known_hosts file
    automatically on first connect. If the key later changes (router
    rebuild, replacement, or a man-in-the-middle) the connection will fail
    until the stale entry is removed from known_hosts, which is the
    intended behaviour for a monitoring tool. Set
    ssh_strict_host_key_checking=no to trust any key silently, or
    ssh_strict_host_key_checking=yes to require the key be pre-populated in
    known_hosts before the probe will connect.

  Requirements
    This module requires the Net::OpenSSH and IO::Pty perl modules
```