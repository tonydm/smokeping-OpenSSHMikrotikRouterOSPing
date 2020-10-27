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

The Mikrotik RouterOS device should have a username/password configured, and
the ssh server must not be disabled.  You can use a non standard port.

Make sure to connect to the remote host once from the command line as the
user who is running smokeping. On the first connect ssh will ask to add the
new host to its known_hosts file. This will not happen automatically so the
script will fail to login until the ssh key of your Mikrotik RouterOS device
is in the known_hosts file.

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

# Check for existing multiplex configuration
# in know locations
sub check_for_multiplex_config($) {
  my $user_home_dir = shift;
  my @files = ("/etc/ssh/config", "/etc/ssh/ssh_config", "$user_home_dir/.ssh/config");
  foreach my $conffile (@files) {
    foreach my $file ($conffile) {
      open my $fh, '<:encoding(UTF-8)', $file or warn;
      while (my $line = <$fh>) {
        if ($line =~ /^\s+ControlMaster\s+(yes|auto)/) {
          if ( $debug ) {
            DEBUG("$debug_key: WARNING! $file contains a ControlMaster config entry!  This may conflict with or override the Probe OpenSSHMikrotikRouterOSPing config!")
          }
        }
      }
    }
  }
}

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
  my $multiplex_ssh = $target->{vars}{multiplex_ssh};
  $multiplex_control_socket_path = $target->{vars}{multiplex_control_socket_path};
  my $multiplex_control_persist_time = $target->{vars}{multiplex_control_persist_time};
  $debug = $target->{vars}{debug};
  my $debug_logfile = $target->{vars}{debug_logfile};

  # Handle true/false strings for options params since perl does
  # not have true/false boolean operators
  $multiplex_ssh = ($multiplex_ssh eq 'true') ? 1 : undef;
  $debug = ($debug eq 'true') ? 1 : undef;
  $do_not_fragment = ($do_not_fragment eq 'true') ? 1 : undef;

  # If Debugging enabled
  $debug_key = gen_debug_key;
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
    DEBUG("$debug_key: Debugging enabled...\n");
  }

  # Define the base SSH connection options to pass to the Net::OpenSSH->new() connection method
  my %opts = (
    "user" => $login ? $login : (),
    "password" => $password ? $password : (),
    "port" => $port,
    "timeout" => 60,
    "strict_mode" => 0,
    "ssh_cmd" => $ssh_cmd
  );

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
        # Ensure master control socket path exists and set permissions
        # Path does not exist, create and set permissions
        `mkdir -p $master_control_socket_dir`;
        `chown -R $script_user:$script_user $master_control_socket_dir`;
        `chmod -R 0744 $master_control_socket_dir`;
        DEBUG("$debug_key: Multiplex control socket file path created and premissions set!");
      }
    }

    if(-e $master_control_socket_path_file){
      # If a multiplex connection socket has already been created, use it
      if ( $debug ) {
        DEBUG("$debug_key: Master Control Socket file: $master_control_socket_path_file exists... Using.\n");
      }

      # Append options hash to use existing multiplex control socket
      $opts{'external_master'} = 1;
      $opts{'ctl_path'} = $master_control_socket_path_file;
    } else {
      # No multiplex connection socket has been created for this host, so create one
      if ( $debug ) {
        DEBUG("$debug_key: Master Control Socket file: $master_control_socket_path_file does not exist!  Creating new socket file.\n");
      }

      # Append options hash to create a multiplex control socket
      $opts{'ctl_dir'} = $master_control_socket_dir;
      $opts{'ctl_path'} = $master_control_socket_path_file;
      $opts{'master_opts'} = ["-oStrictHostKeyChecking=no", "-oControlPersist=$multiplex_control_persist_time", "-vvv"];
    }
  } else {
    # $self->do_log("Not using OpenSSH ControlMaster Multiplex connections!\n");
  }

  # # DEBUG
  # $Net::OpenSSH::debug = -1;

  # Debug - Show SSH Options Hash
  if ( $debug ) {
    my $resp = Dumper \%opts;
    DEBUG("$debug_key: Net::OpenSSH->new options:\n$resp");
  }

  # Connect to source host
  my $ssh = Net::OpenSSH->new(
    $host, %opts
  );

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

  # Debug - Show ping command
  if ( $debug ) {
    DEBUG("$debug_key: $ping_command");
  }

  # Execute the ping command on the source/host and capture the response
  my @output = ();
  @output = $ssh->capture($ping_command);

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

  # Parse the ping latency values
  while (@output) {
    my $outputline = shift @output;
    chomp($outputline);
    next if ($outputline =~ m/(sent|recieved|packet\-loss|min\-rtt|avg\-rtt|max\-rtt)/);
    $outputline =~ /(\d+)ms/ && push(@times,$1);
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

  # Debug
  if ( $debug ) {
    my $resp = Dumper \@times;
    my $length = @times;
    DEBUG("$debug_key: \@times result: length[$length]\n$resp\n");
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
    _mandatory => [ 'routerosuser', 'routerospass', 'source' ],
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
The (manditory) routerospass option allows you to specify the SSH login password.
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
debugging.
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
The (optional) debug_logfile option lets you specify the debug logifile
DOC
      _default => "/tmp/smokeping_debug.log",
      _example => "/tmp/my_debug.log or /tmp/smokeping_target1.log"
    }
  };

  return $class->_makevars($h, $params);
}

1;