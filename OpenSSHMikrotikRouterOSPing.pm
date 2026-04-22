package Smokeping::probes::OpenSSHMikrotikRouterOSPing;

=head1 301 Moved Permanently

This is a Smokeping probe module. Please use the command

C<smokeping -man Smokeping::probes::OpenSSHMikrotikRouterOSPing>

to view the documentation or the command

C<smokeping -makepod Smokeping::probes::OpenSSHMikrotikRouterOSPing>

to generate the POD document.

=cut

use strict;

use base qw(Smokeping::probes::basefork);
use Net::OpenSSH;
use Carp;
use Time::HiRes qw(time);

# Global VARs for Debugging & Multiplexing SSH Connections
my $debug;
my $debug_key;
my $master_control_socket_dir;
my $multiplex_control_socket_path;
my $master_control_socket_path_file;
my $master_control_socket_file;

#
# Begin Subroutines
#

my $e = "=";
sub pod_hash {
  return {
  name => <<DOC,
Smokeping::probes::OpenSSHMikrotikRouterOSPing - Mikrotik RouterOS SSH Probe for SmokePing
DOC
  description => <<DOC,
Connect to Mikrotik RouterOS Device via OpenSSH to run ping commands.
This probe uses the "ping" cli of the Mikrotik RouterOS.  You have
options to specify which interface the ping is sourced from, which
routing table to use and multiplexd ssh connections, as well as others.
DOC
  notes => <<DOC,
${e}head2 Mikrotik RouterOS configuration

The Mikrotik RouterOS device should have a username configured, and the
ssh server must not be disabled.  You can use a non standard port.  The
user needs either a password set or an ssh public key associated with it
via /user ssh-keys import on the router.

${e}head2 Authentication

The probe supports three ways to authenticate to the Mikrotik RouterOS
device.  Pick one per target.

=over

=item * Password: set routerospass.  Leave ssh_key_path unset.  This is
the legacy default.

=item * SSH key file: set ssh_key_path to the path of a private key
file readable by the user running smokeping.  When ssh_key_path is set
it takes precedence over any routerospass inherited from the probe-level
default, so you can flip individual targets to key auth without having
to unset routerospass on the parent.  Install the matching public key
on the router with /user ssh-keys import public-key-file=<file>
user=<routerosuser>.  The README has a step-by-step walk-through.

=item * ssh-agent or system default identity: leave both routerospass
and ssh_key_path unset.  Net::OpenSSH will invoke the system ssh client
which picks up SSH_AUTH_SOCK, ~/.ssh/id_ed25519, ~/.ssh/id_rsa etc as
it would for an interactive login.  This is useful for containerised
smokeping deployments that mount an agent socket.

=back

If none of the three are configured the connection will fail at runtime
with a Net::OpenSSH authentication error logged to the smokeping log.

By default (ssh_strict_host_key_checking=accept-new) the probe will add the
router's host key to the smokeping user's known_hosts file automatically on
first connect. If the key later changes (router rebuild, replacement, or a
man-in-the-middle) the connection will fail until the stale entry is
removed from known_hosts, which is the intended behaviour for a monitoring
tool. Set ssh_strict_host_key_checking=no to trust any key silently, or
ssh_strict_host_key_checking=yes to require the key be pre-populated in
known_hosts before the probe will connect.

${e}head2 Requirements

This module requires the  L<Net::OpenSSH> and L<IO::Pty> perl modules.
DOC
  authors => <<'DOC',
Tony DeMatteis E<lt>tonydema@gmail.comE<gt>

based on L<Smokeping::Probes::OpenSSHJunOSPing> by Tobias Oetiker E<lt>tobi@oetiker.chE<gt>,
which itself is
based on L<Smokeping::probes::TelnetJunOSPing> by S H A N E<lt>shanali@yahoo.comE<gt>.

Additional Credits:
  Routing Table option - https://github.com/leostereo  Leandro needed to be able to specify
  a specific routing table.  Leandro contribuited code suggestions to enable this
  functionality
DOC
  }
}

sub new($$$){
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = $class->SUPER::new(@_);

  $self->{pingfactor} = 1000; # Gives us a good-guess default

  return $self;
}

sub ProbeDesc($){
  my $self = shift;
  my $bytes = $self->{properties}{packetsize};
  return "Mikrotik RouterOS - ICMP Echo Pings ($bytes Bytes)";
}

# Generate a random string to use a debug log thread key
sub gen_debug_key(){
	my @set = ('0' ..'9', 'A' .. 'F');
	my $str = join '' => map $set[rand @set], 1 .. 10;
  return $str;
}

# Render a copy-pasteable approximation of the ssh invocation that
# Net::OpenSSH will execute.  Useful for reproducing failures manually.
# Does not include password auth details: Net::OpenSSH feeds the password
# via a pty, not the command line, so the rendered command won't include
# it.  key_path IS rendered (as -i <path>) because Net::OpenSSH translates
# the key_path option into an -i flag on the underlying ssh invocation.
sub render_ssh_command {
  my ($ssh_cmd, $master_opts, $port, $user, $host, $key_path, $command) = @_;
  my @parts = ($ssh_cmd, @$master_opts);
  push @parts, "-i", $key_path if $key_path;
  push @parts, "-p", $port if $port;
  push @parts, ($user ? "$user\@$host" : $host);
  # $command ends with "\n" (required by $ssh->capture for RouterOS CLI
  # line termination) and may carry other trailing whitespace.  Strip it
  # before wrapping in single quotes so the closing quote stays on the
  # same log line.
  (my $clean_command = $command) =~ s/\s+\z//;
  push @parts, "'" . $clean_command . "'";
  return join(" ", @parts);
}

# Check for existing multiplex configuration
# in know locations
sub check_for_multiplex_config($) {
  my $user_home_dir = shift;
  my @files = ("/etc/ssh/config", "/etc/ssh/ssh_config", "$user_home_dir/.ssh/config");
  foreach my $conffile (@files) {
    foreach my $file ($conffile) {
  		open my $fh, $file || warn $!;  
      while (my $line = <$fh>) {
        if ($line =~ /^\s+ControlMaster\s+(yes|no|ask|auto)/) {
          if ( $debug ) {
            DEBUG("$debug_key: WARNING! $file contains a ControlMaster config entry!  This may conflict with or override the Probe OpenSSHMikrotikRouterOSPing config!")
          }
        }
      }
    }
  }
}

# Where the magic happens
sub pingone ($$){
  my $self = shift;
  my $target = shift;
  my $host = $target->{vars}{source};
  my $port = $target->{vars}{ssh_port};
  my $login = $target->{vars}{routerosuser};
  my $password = $target->{vars}{routerospass};
  my $dest = $target->{vars}{host};
  my $psource = $target->{vars}{psource};
  my $bytes = $self->{properties}{packetsize};
  my $pings = $self->pings($target);
  my $rtable = $target->{vars}{rtable};
  my $interface = $target->{vars}{interface};
  my $dscp_id = $target->{vars}{dscp_id};
  my $ttl = $target->{vars}{ttl};
  my $do_not_fragment = $target->{vars}{do_not_fragment};
  my $ssh_cmd = $target->{vars}{ssh_binary_path};
  my $ssh_key_path = $target->{vars}{ssh_key_path};
  my $ssh_timeout = $target->{vars}{ssh_timeout};
  my $ssh_connect_timeout = $target->{vars}{ssh_connect_timeout};
  my $ssh_strict_host_key_checking = $target->{vars}{ssh_strict_host_key_checking};
  my $multiplex_ssh = $target->{vars}{multiplex_ssh};
  $multiplex_control_socket_path = $target->{vars}{multiplex_control_socket_path};
  my $multiplex_control_persist_time = $target->{vars}{multiplex_control_persist_time};
  $debug = $target->{vars}{debug};
  my $debug_logfile = $target->{vars}{debug_logfile};
  my $debug_ssh = $target->{vars}{debug_ssh};

  # Handle true/false strings for options params since perl does
  # not have true/false boolean operators
  $multiplex_ssh = ($multiplex_ssh eq 'true') ? 1 : undef;
  $do_not_fragment = ($do_not_fragment eq 'true') ? 1 : undef;
  $debug = ($debug eq 'true') ? 1 : undef;
  $debug_ssh = ($debug_ssh eq 'true') ? 1 : undef;

  # If Debugging enabled
  $debug_key = gen_debug_key;
  my $t_cycle_start = time();
  my $auth_method = $ssh_key_path ? "key($ssh_key_path)"
                  : $password     ? "password"
                  :                 "agent/default";
  if ( $debug ) {
    use Data::Dumper;

    use Log::Log4perl qw(:easy);
    Log::Log4perl->easy_init(
      {
        file  => ">> $debug_logfile",
        level => $ERROR,
      },
      {
        file  => "STDERR",
        level => $DEBUG,
      }
    );
    DEBUG(sprintf(
      "%s: cycle start: host=%s dest=%s user=%s auth=%s multiplex=%s " .
      "strict_host_key=%s connect_timeout=%ds timeout=%ds",
      $debug_key, $host, $dest, $login, $auth_method,
      ($multiplex_ssh ? "on" : "off"),
      $ssh_strict_host_key_checking, $ssh_connect_timeout, $ssh_timeout,
    ));
  }

  # Define the base SSH connection options to pass to the Net::OpenSSH->new() connection method.
  # Note the conditional-pair idiom: ($val ? (key => $val) : ()) either adds both key and
  # value, or adds neither.  The older form "key" => ($val ? $val : ()) produces a bare
  # "key" with no value when $val is falsy, which corrupts the hash (odd element count).
  #
  # Auth precedence: ssh_key_path wins over routerospass.  Net::OpenSSH refuses to accept
  # both key_path and password in the same call ("Invalid or bad combination of options"),
  # so when a target sets ssh_key_path we drop any password inherited from the probe-level
  # routerospass default.  If neither is set, Net::OpenSSH falls through to ssh-agent /
  # default identity files.
  my %opts = (
    ($login        ? ("user"     => $login       ) : ()),
    ($ssh_key_path ? ("key_path" => $ssh_key_path)
                   : ($password ? ("password" => $password) : ())),
    "port"                => $port,
    "timeout"             => $ssh_timeout,
    "kill_ssh_on_timeout" => 1,
    "strict_mode"         => 0,
    "ssh_cmd"             => $ssh_cmd,
  );

  # Base master_opts applied whether or not multiplexing is enabled.
  # -oConnectTimeout bounds the TCP handshake so an unreachable router fails
  # fast instead of waiting the full ssh_timeout. -oStrictHostKeyChecking
  # defaults to accept-new so new routers auto-add on first connect but a
  # changed key raises a visible failure in smokeping.
  my @master_opts = (
    "-oStrictHostKeyChecking=$ssh_strict_host_key_checking",
    "-oConnectTimeout=$ssh_connect_timeout",
  );
  push @master_opts, "-vvv" if $debug_ssh;
  $opts{'master_opts'} = \@master_opts;

  # If multiplex ssh is enabled
  if ( $multiplex_ssh ){
    if ( $debug ) {
      DEBUG("$debug_key: Using OpenSSH ControlMaster Multiplex connections!\n");
    }

    # Try and determine user executing script user in order to determine /home dir location for
    # Master Control Socket file
    my $script_user = $ENV{LOGNAME} || $ENV{USER} || getpwuid($<);
    my $script_user_home_dir = (getpwuid $>)[7];

    check_for_multiplex_config($script_user_home_dir);

    # Set master control path and filename vars now that we know $USER home dir
    $master_control_socket_dir = $multiplex_control_socket_path ? $multiplex_control_socket_path : "$script_user_home_dir/.libnet-openssh-perl";
    $master_control_socket_file = 'control-smokeping@' . $host;
    $master_control_socket_path_file = "$master_control_socket_dir/$master_control_socket_file";
    $multiplex_control_persist_time = $multiplex_control_persist_time ? "$multiplex_control_persist_time" . "m" : ();

    if (-d $master_control_socket_dir) {
      # Path exists, nothing to do
    } else {
      if ( $debug ) {
        DEBUG("$debug_key: Multiplex control socket file path: [$master_control_socket_dir] does not exist!  Creating...");
      }
      
      # Ensure master control socket path exists and set permissions
      # Path does not exist, create and set permissions
      `mkdir -p $master_control_socket_dir`;
      `chown -R $script_user:$script_user $master_control_socket_dir`;
      `chmod -R 0744 $master_control_socket_dir`;

      if ( $debug ) {
        DEBUG("$debug_key: Multiplex control socket file path created and permissions set!");
      }
    }

    if( -e $master_control_socket_path_file ){
      # If a multiplex connection socket has already been created, use it
      if ( $debug ) {
        DEBUG("$debug_key: Master Control Socket file: $master_control_socket_path_file exists... Using.\n");
      }

      # Append options hash to use existing multiplex control socket.
      # Net::OpenSSH forbids master_opts alongside external_master (no master
      # is being spawned, so master-side flags are meaningless), so drop it.
      delete $opts{'master_opts'};
      $opts{'external_master'} = 1;
      $opts{'ctl_path'} = $master_control_socket_path_file;
    } else {
      # No multiplex connection socket has been created for this host, so create one
      if ( $debug ) {
        DEBUG("$debug_key: Master Control Socket file: $master_control_socket_path_file does not exist!  Creating new socket file.\n");
      }

      # Add multiplex-specific options to the base master_opts list
      push @master_opts, "-oControlPersist=$multiplex_control_persist_time";

      # Append options hash to create a multiplex control socket
      $opts{'ctl_dir'} = $master_control_socket_dir;
      $opts{'ctl_path'} = $master_control_socket_path_file;
    }
  } else {
    # $self->do_log("Not using OpenSSH ControlMaster Multiplex connections!\n");
  }

  # DEBUG SSH Connection Detail
  open my $ssh_debug_out, '>>', $debug_logfile || warn $!;
  DEBUG("debug:-ssh: $debug_ssh") unless ( ! $debug_ssh );
  $Net::OpenSSH::debug_fh = $ssh_debug_out unless ( ! $debug_ssh );
  $Net::OpenSSH::debug = -1 unless ( ! $debug_ssh );

  # Debug - Show SSH Options Hash
  if ( $debug ) {
    my $resp = Dumper \%opts;
    DEBUG("$debug_key: Net::OpenSSH->new options:\n$resp");
  }

  # Connect to source host
  my $t_conn_start = time();
  my $ssh = Net::OpenSSH->new(
    $host, %opts
  );
  my $t_conn_end = time();

  if ( $debug_ssh ) {
    DEBUG("SSH ERROR: " . $ssh->error );
  }

  # Return to caller if SSH connection error
  if ($ssh->error) {
    $self->do_log( "OpenSSHMikrotikRouterOSPing connecting $host: ".$ssh->error );
    return ();
  };

  # Build ping command
  my $ping_command = "ping $dest";

  if ( $psource ) {
    $ping_command .= " src-address=$psource";
  }

  if ( $interface ) {
    $ping_command .= " interface=$interface";
  }

  if ( $pings ) {
    $ping_command .= " count=$pings";
  }

  if ( $bytes ) {
    $ping_command .= " size=$bytes";
  }

  if ( $rtable ) {
    $ping_command .= " routing-table=$rtable";
  }

  if ( $dscp_id ) {
    $ping_command .= " dscp=$dscp_id";
  }

  if ( $ttl && $ttl != 64 ) {
    $ping_command .= " ttl=$ttl";
  }

  if ( $do_not_fragment ) {
    $ping_command .= " do-not-fragment";
  }

  $ping_command .= "\n";

  # Debug - Show ping command + the full composed ssh invocation it will be sent through
  if ( $debug ) {
    DEBUG("$debug_key: $ping_command");
    my $rendered = render_ssh_command(
      $ssh_cmd, \@master_opts, $port, $login, $host, $ssh_key_path, $ping_command
    );
    DEBUG("$debug_key: ssh command: $rendered");
  }

  # Execute the ping command on the source/host and capture the response
  my @output = ();
  my $t_cmd_start = time();
  @output = $ssh->capture($ping_command);
  my $t_cmd_end = time();

  if ($ssh->error) {
    $self->do_log( "OpenSSHMikrotikRouterOSPing running commands on $host: ".$ssh->error );
    return ();
  };

  # Debug
  if ( $debug ) {
    my $resp = join("$debug_key: ", @output);
    DEBUG("$debug_key: ========== Ping response ==========\n$resp\n");
  }

  # Process the ping response
  my @times = ();
  my $router_summary;
  my $t_parse_start = time();

  # Parse the ping latency values.  The RouterOS summary footer "sent=N
  # received=N packet-loss=N%" is captured separately so we can log it and
  # cross-check the parser against the router's own accounting.  The
  # min/avg/max-rtt footer line is still skipped to avoid accidentally
  # matching the embedded rtt values with the sample-line regex.
  while (@output) {
    my $outputline = shift @output;
    chomp($outputline);
    if ($outputline =~ /sent=(\d+)\s+received=(\d+)\s+packet-loss=(\d+)%/) {
      $router_summary = { sent => $1, received => $2, loss => $3, raw => $outputline };
      next;
    }
    next if ($outputline =~ m/(min\-rtt|avg\-rtt|max\-rtt)/);
    $outputline =~ /((\d+)ms(\d+)us|(\d+)ms|(\d+)us)\s*$/ && push(@times,($2?$2:"")+($4?$4:"")+($3?$3/1000:"")+($5?$5/1000:""));
  }

  # Convert the ping times values to RRD format
  @times = map {sprintf "%.10e", $_ / $self->{pingfactor}} sort {$a <=> $b} @times;

  # Ensure the number of pings returned in @tumes are equal to the
  # configured number of pings defined in the host definition.  Any value
  # other than the number defined in the RRD format will cause the RRD update
  # to fail
  my $length = @times;
  while (($length = @times) > 20) {
    pop @times;
  }
  my $t_parse_end = time();

  # Debug
  if ( $debug ) {
    my $resp = Dumper \@times;
    my $length = @times;
    DEBUG("$debug_key: \@times result: length[$length]\n$resp\n");

    if ( $router_summary ) {
      DEBUG("$debug_key: router summary: $router_summary->{raw}");
      if ( $router_summary->{received} != $length ) {
        DEBUG(sprintf(
          "%s: WARN parser drift: router received=%d but parser built %d samples",
          $debug_key, $router_summary->{received}, $length,
        ));
      }
    }

    my $ms = sub { sprintf("%.0fms", ($_[1] - $_[0]) * 1000) };
    DEBUG(sprintf(
      "%s: cycle done: connect=%s command=%s parse=%s total=%s samples=%d",
      $debug_key,
      $ms->($t_conn_start,  $t_conn_end),
      $ms->($t_cmd_start,   $t_cmd_end),
      $ms->($t_parse_start, $t_parse_end),
      $ms->($t_cycle_start, time()),
      $length,
    ));
  }

  return @times;
}

# Params defined - param name, default value, eval allowed value, documentation
sub probevars {
  my $class = shift;
  return $class->_makevars($class->SUPER::probevars, {
    packetsize => {
      _doc => <<DOC,
The (optional) packetsize option lets you configure the packetsize for
the pings sent.  You cannot ping with packets larger than the MTU of
the source interface, so the packet size should always be equal to or less than
the MTU on the interface.  MTU size can vary on each model of the Mikrotik
RouterBoard.  Reference your model for appropriate values if you wish to override.
DOC
      _default => 56,
      _re => '\d+',
      _sub => sub {
        my $val = shift;
        return "ERROR: packetsize of $val is invalid.  Must be between 12 and 10226"
          unless $val >= 12 and $val <= 10226;
        return undef;
      },
    },
  });
}

sub targetvars {
  my $class = shift;
  my $h = $class->SUPER::targetvars;
  delete $h->{pings};

  # Find and set default master control socket path if not user defined
  my $script_user_home_dir = (getpwuid $>)[7];
  my $default_socket_dir = $script_user_home_dir ? $script_user_home_dir : "/tmp/smokeping_ssh_sockets";

  # Define the parameters/options
  my $params = {
    _mandatory => [ 'routerosuser', 'source' ],
    source => {
      _doc => <<DOC,
The (manditory) source option specifies the Mikrotik RouterOS device that is going to run
the ping commands.  This address will be used for the ssh connection.
DOC
      _example => "192.168.2.1",
    },
    psource => {
      _doc => <<DOC,
The (optional) psource option specifies an alternate IP address or
Interface from which you wish to source your pings from.  Mikrotik routers
can have many many IP addresses, and interfaces.  When you ping from a
router you have the ability to choose which interface and/or which IP
address the ping is sourced from.  Specifying an IP/interface does not
necessarily specify the interface from which the ping will leave, but
will specify which address the packet(s) appear to come from.  If this
option is left out the Mikrotik RouterOS Device will source the packet
automatically based on routing and/or metrics.  If this doesn't make sense
to you then just leave it out.
DOC
      _example => "192.168.2.129",
    },
    routerosuser => {
      _doc => <<DOC,
The (manditory) routerosuser option allows you to specify the SSH login username 
that has ping capability on the Mikrotik RouterOS Device.
DOC
      _example => 'user',
    },
    routerospass => {
      _doc => <<DOC,
The (optional) routerospass option specifies the SSH login password.
Required unless ssh_key_path is set, or ssh-agent / a default identity
file (e.g. ~/.ssh/id_ed25519) is configured for the user running
smokeping.  See the Authentication section in the notes.

Note: when debug=true the value of routerospass is written to
debug_logfile in plaintext as part of the Net::OpenSSH options dump.
See the debug option for details and mitigation.
DOC
      _example => 'password',
    },
    rtable => {
      _doc => <<DOC,
The (optional) rtable option lets you specify the routing table to use in the
ping command.
DOC
    _example => 'secondary_route'
    },
    pings => {
      _doc => <<DOC,
The (optional) pings option lets you specify the number of pings sent.
A reasonable max value is 20.  However, a max value of 50 is allowed.
DOC
      _default => 20,
      _re => '\d+',
      _sub => sub {
        my $val = shift;
        return "ERROR: ping value of $val is invalid.  Must be >= 1 and <= 50"
          unless $val >= 1 and $val <= 50;
        return undef;
      },
      _example => "20"
    },
    interface => {
      _doc => <<DOC,
The (optional) interface option lets you specify the name of the interface
to source pings.
DOC
      _example => 'ether1'
    },
    ttl => {
      _doc => <<DOC,
The (optional) ttl option lets you specify the Time to Live value for
the pings sent.  Default is 64.
DOC
      # _default => 64,
      _re => '\d+',
      _sub => sub {
        my $val = shift;
        return "ERROR: ttl value of $val is invalid.  Must be >= 1 and <= 255"
          unless $val >= 1 and $val <= 255;
        return undef;
      },
      _example => "20",
    },
    dscp_id => {
      _doc => <<DOC,
The (optional) dscp_id option lets you specify the DSCP ID.
DOC
#      _default => ,
      _re => '\d+',
      _sub => sub {
        my $val = shift;
        return "ERROR: dscp value of $val is invalid.  Must be an integer between 1 and 63."
          unless $val >= 1 and $val <= 63;
        return undef;
      },
      _example => 20,
    },
    do_not_fragment => {
      _doc => <<DOC,
The (optional) do_not_fragment option lets you specify the do-not-fragment flag.
If the flag is set packets will not be fragmented if size exceeds interface mtu.
DOC
      _default => 'false',
      _re => '\w+',
      _sub => sub {
        my $val = shift;
        return "ERROR: do_not_fragment value of $val is invalid.  Must be true or false"
          unless $val == 'true' or $val == 'false';
        return undef;
      },
      _example => 'true',
    },
    ssh_port => {
      _doc => <<DOC,
The (optional) ssh_port option lets you specify a non standard SSH port.
DOC
      _re => '\d+',
      _default => 22,
      _example => 22431,
    },
    ssh_binary_path => {
      _doc => <<DOC,
The (optional) ssh_binary_path option lets you specify the path for the ssh client binary.
This option will specify the path to the Net::OpenSSH host connector.  It may be
necessary to define the path to the binary if it is not found in the \$PATH.
DOC
      _default => "/usr/bin/ssh",
      _example => "/usr/bin/ssh",
    },
    ssh_key_path => {
      _doc => <<DOC,
The (optional) ssh_key_path option specifies the path to a private key
file used to authenticate to the Mikrotik RouterOS device.  When set the
ssh client is invoked with -i <path>, bypassing routerospass.  The key
must be readable only by the user running smokeping (typically mode
0600) or the ssh client will refuse to use it.  See the Authentication
section in the notes for the three supported modes (password, key file,
ssh-agent / default identity files).
DOC
      _example => '/etc/smokeping/id_ed25519',
    },
    ssh_connect_timeout => {
      _doc => <<DOC,
The (optional) ssh_connect_timeout option bounds the TCP/SSH handshake in
seconds via OpenSSH's ConnectTimeout option.  This is the main knob for
failing fast when the Mikrotik RouterOS device is unreachable, so probe
cycles do not blow out waiting the full ssh_timeout.  Must be less than
ssh_timeout.
DOC
      _default => 10,
      _re => '\d+',
      _sub => sub {
        my $val = shift;
        return "ERROR: ssh_connect_timeout value of $val is invalid.  Must be >= 1 and <= 300"
          unless $val >= 1 and $val <= 300;
        return undef;
      },
      _example => 10,
    },
    ssh_timeout => {
      _doc => <<DOC,
The (optional) ssh_timeout option specifies, in seconds, the Net::OpenSSH
master-channel timeout.  This bounds the overall duration of the ssh
session including the running ping command, so it must be larger than the
ping command duration (roughly pings * 1s + headroom).  For short TCP
handshake timeouts see ssh_connect_timeout.
DOC
      _default => 60,
      _re => '\d+',
      _sub => sub {
        my $val = shift;
        return "ERROR: ssh_timeout value of $val is invalid.  Must be >= 1 and <= 3600"
          unless $val >= 1 and $val <= 3600;
        return undef;
      },
      _example => 60,
    },
    ssh_strict_host_key_checking => {
      _doc => <<DOC,
The (optional) ssh_strict_host_key_checking option controls OpenSSH's
StrictHostKeyChecking policy for the ssh connection to the Mikrotik
RouterOS device.  Valid values: 'accept-new' (default - auto-adds new
host keys to known_hosts on first connect, rejects changed keys), 'no'
(silently trust any host key), 'yes' (require key to already be in
known_hosts, fail otherwise).
DOC
      _default => 'accept-new',
      _re => '(yes|accept-new|no)',
      _sub => sub {
        my $val = shift;
        return "ERROR: ssh_strict_host_key_checking value of $val is invalid.  Must be yes, accept-new, or no"
          unless $val eq 'yes' or $val eq 'accept-new' or $val eq 'no';
        return undef;
      },
      _example => 'accept-new',
    },
    multiplex_ssh => {
      _doc => <<DOC,
The (optional) multiplex_ssh option lets you specify whether to use multiplexed
ssh connections, i.e. reuse the same SSH connection to a host.
DOC
      _default => 'true',
      _re => '\w+',
      _sub => sub {
        my $val = shift;
        return "ERROR: multiplex_ssh value of $val is invalid.  Must be true or false"
          unless $val == 'true' or $val == 'false';
        return undef;
      },
      _example => 'false'
    },
    multiplex_control_persist_time => {
      _doc => <<DOC,
The (optional) multiplex_control_persist_time option lets you specify, in
minutes, how long to persist the multiplex or Master Control Socket.
ControlMaster sockets are removed automatically when the master connection
has ended. If multiplex_control_persist_time is set to 0, the master connection open
will be left open in the background to accept new connections until killed
explicitly or ends at a pre-defined timeout.  If multiplex_control_persist_time
is set to a time, then it will leave the master connection open for the
designated time or until the last multiplexed session is closed, whichever is longer.
DOC
      _default => 10, # 10 Min
      _re => '\d+',
      _sub => sub {
        my $val = shift;
        return "ERROR: multiplex_control_persist_time value of $val is invalid.  Must be >= 1 and <= 1000"
          unless $val >= 1 and $val <= 1000;
        return undef;
      },
      _example => 20
    },
    multiplex_control_socket_path => {
      _doc => <<DOC,
The (optional) multiplex_control_socket_path ssh option lets you specify the
master control socket path
DOC
      _default => $default_socket_dir . "/.libnet-openssh-perl",
      _example => "/tmp/smokeping_ssh_sockets"
    },
    debug => {
      _doc => <<DOC,
The (optional) debug option lets you configure probe or target specific
debugging.  When enabled the log includes a cycle-start configuration
snapshot, the composed ssh command, phase timings (connect/command/parse),
and the RouterOS packet-loss summary cross-checked against the parsed
samples.

Security warning: with debug enabled the log also contains a
Data::Dumper dump of the Net::OpenSSH options hash, which includes
routerospass in plaintext when password auth is in use, and the full
on-disk path of ssh_key_path when key auth is in use.  Ensure
debug_logfile lives on a filesystem readable only by the smokeping user,
and redact the file before sharing it externally (support tickets,
public issue trackers, pastebins, etc.).
DOC
      _default => 'false',
      _re => '\w+',
      _sub => sub {
        my $val = shift;
        return "ERROR: debug option value of $val is invalid.  Must be true or false"
          unless $val == 'true' or $val == 'false';
        return undef;
      },
      _example => 'true'
    },
    debug_logfile => {
      _doc => <<DOC,
The (optional) debug_logfile option lets you specify the debug logifile.

With debug=true this file contains sensitive material including the
target's routerospass (when password auth is used) and the on-disk path
of ssh_key_path.  Treat it as secret: lock it down with filesystem
permissions readable only by the smokeping user, and rotate/redact it
before sharing externally.
DOC
      _default => "/tmp/smokeping_debug.log",
      _example => "/tmp/my_debug.log or /tmp/smokeping_target1.log"
    },
    debug_ssh => {
      _doc => <<DOC,
The (optional) debug option lets you configure probe or target specific
ssh debugging.
DOC
      _default => 'false',
      _re => '\w+',
      _sub => sub {
        my $val = shift;
        return "ERROR: debug option value of $val is invalid.  Must be true or false"
          unless $val == 'true' or $val == 'false';
        return undef;
      },
      _example => 'true'
    }
  };

  return $class->_makevars($h, $params);
}

1;
