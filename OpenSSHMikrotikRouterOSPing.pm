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

# # Debugging
# use Data::Dumper;

# use Log::Log4perl qw(:easy);
# Log::Log4perl->easy_init(
#   {
#     file  => ">> /tmp/openssh_error_log",
#     level => $ERROR,
#   },
#   {
#     file  => "STDERR",
#     level => $DEBUG,
#   }
# );
# DEBUG("Debugging enabled...\n");

my $e = "=";
sub pod_hash {
  return {
  name => <<DOC,
Smokeping::probes::OpenSSHMikrotikRouterOSPing - Mikrotik RouterOS SSH Probe for SmokePing
DOC
  description => <<DOC,
Connect to Mikrotik RouterOS Device via OpenSSH to run ping commands.
This probe uses the "ping" cli of the Mikrotik RouterOS.  You have
the options to specify which interface the ping is sourced from, which
routing table to use and multiplexd ssh connections.
DOC
  notes => <<DOC,
${e}head2 Mikrotik RouterOS configuration

The Mikrotik RouterOS device should have a username/password configured, and
the ssh server must not be disabled.

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
  Routing Table option - https://github.com/leostereo  Leandro contribuited suggestions and code
  to be able to specify a specific routing table.  Thank you
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
  my $rtable = $self->{vars}{rtable};
  my $ssh_cmd = $target->{vars}{ssh_binary_path};
  my $multiplex_ssh = $target->{vars}{multiplex_ssh};
  my $multiplex_control_persist_time = $target->{vars}{multiplex_control_persist_time};
  my $multiplex_control_socket_path = $target->{vars}{multiplex_control_socket_path};
  my $pings = $self->pings($target);

  # Try and determine script user in order to determine /home dir location for
  # Master Control Socket file
  my $script_user = $ENV{LOGNAME} || $ENV{USER} || getpwuid($<);
  my $script_user_home_dir = (getpwuid $>)[7];

  # TODO (Add automatic home dir, tests, and fallback dir)
  my $master_control_socket_dir = $multiplex_control_socket_path ? $multiplex_control_socket_path : "$script_user_home_dir/.libnet-openssh-perl";
  my $master_control_socket_file = 'control-smokeping@' . $host;
  my $master_control_socket_path_file = "$master_control_socket_dir/$master_control_socket_file";
  $multiplex_control_persist_time = $multiplex_control_persist_time ? "$multiplex_control_persist_time" . "m" : ();

  # do NOT call superclass ... the ping method MUST be overwriten
  my %upd;
  my @args = ();

  #  Define the base SSH connection options to pass to the Net::OpenSSH->new() connection method
  my %opts = (
    "user" => $login ? $login : (),
    "password" => $password ? $password : (),
    "port" => $port,
    "timeout" => 60,
    "strict_mode" => 0,
    "ssh_cmd" => $ssh_cmd
  );

  # # DEBUG
  # $Net::OpenSSH::debug = -1;

  my $ssh;

  # If multiplex_ssh connection is true/1, add necessary additional params to options hash
  if ( $multiplex_ssh ) {
    # $self->do_log("Using OpenSSH ControlMaster Multiplex connections!\n");
    if(-e $master_control_socket_path_file){
      # If a multiplex connection socket has already been created, use it
      # $self->do_log("Master Control Socket file: $master_control_socket_path_file exists... Using.\n");

      # Append options hash to use existing multiplex control socket
      $opts{'external_master'} = 1;
      $opts{'ctl_path'} = $master_control_socket_path_file;
    } else {
      # No multiplex connection socket has been created for this host, so create one
      # $self->do_log("Master Control Socket file: $master_control_socket_path_file does not exist!  Creating new socket file.\n");

      # Append options hash to create a multiplex control socket
      $opts{'ctl_dir'} = $master_control_socket_dir;
      $opts{'ctl_path'} = $master_control_socket_path_file;
      $opts{'master_opts'} = ["-oStrictHostKeyChecking=no", "-oControlPersist=$multiplex_control_persist_time", "-vvv"];
    }
  } else {
    # $self->do_log("Not using OpenSSH ControlMaster Multiplex connections!\n");
  }

  # # Debug - Show Options Hash
  # $self->do_log(Dumper \%opts);

  # Connect to source host
  $ssh = Net::OpenSSH->new(
    $host, %opts
  );

  if ($ssh->error) {
    $self->do_log( "OpenSSHMikrotikRouterOSPing connecting $host: ".$ssh->error );
    return ();
  };

  # # Debug
  # $self->do_log("ping $dest count=$pings size=$bytes src-address=$psource");

  # Build ping command
  my $ping_command = "ping $dest";

  if ( $psource ) {
    $ping_command .= " src-address=$psource";
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

  $ping_command .= "\n";

  # Execute the ping command on the source/host and capture the response
  my @output = ();
  @output = $ssh->capture($ping_command);

  if ($ssh->error) {
    $self->do_log( "OpenSSHMikrotikRouterOSPing running commands on $host: ".$ssh->error );
    return ();
  };

  # # Debug
  # $self->do_log('========== Ping response ==========' . "\n");
  # $self->do_log(Dumper \@output);

  # Process the ping response
  my @times = ();

  while (@output) {
    my $outputline = shift @output;
    chomp($outputline);
    next if ($outputline =~ m/(sent|recieved|packet\-loss|min\-rtt|avg\-rtt|max\-rtt)/);
    $outputline =~ /(\d+)ms/ && push(@times,$1);
  }

  # Convert the ping times values to RRD format
  @times = map {sprintf "%.10e", $_ / $self->{pingfactor}} sort {$a <=> $b} @times;
  
  # Ensure the number of pings requested returned by @tumes are equal to the
  # configured number of pings defined in the host definition.  Any value
  # other than the number defined in the RRD format will cause the update
  # to fail
  my $length = @times;
  while (($length = @times) > 20) {
    $self->do_log('@times length: ' . $length . "\n");
    pop @times;
  }

  # # Debug
  # $self->do_log('@times:');
  # $self->do_log(Dumper \@times);
  # my $length = @times;
  # $self->do_log("Length of times: $length");

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

  # Define the parameters/options
  my $params = {
    _mandatory => [ 'routerosuser', 'routerospass', 'source' ],
    source => {
      _doc => <<DOC,
The source option specifies the Mikrotik RouterOS device that is going to run
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
The routerosuser option allows you to specify the SSH login username and 
that has ping capability on the Mikrotik RouterOS Device.
DOC
      _example => 'user',
    },
    routerospass => {
      _doc => <<DOC,
The routerospass option allows you to specify the SSH login password.
DOC
      _example => 'password',
    },
    rtable => {
      _doc => <<DOC,
The (optional) rtable option lets you specify the routing table to use in the
ping command.
DOC
    _default => ''
    },
    pings => {
      _doc => <<DOC,
The (optional) pings option lets you configure the number of pings for
the pings sent.  A reasonable max value is 20.  However, a max value of 50
allowed.
DOC
      _default => 20,
      _re => '\d+',
      _sub => sub {
        my $val = shift;
        return "ERROR: ping value of $val is invalid.  Must be >= 1 and <= 50"
          unless $val >= 1 and $val <= 50;
        return undef;
      },
      _example => "20",
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
The (optional) multiplex_ssh option lets you configure Net::OpenSSH to use multiplexed
ssh connections.  i.e. reuse the same SSH connection to a host.  Default is enabled (=1)
DOC
      _default => 1, # True
      _re => '\d+',
      _sub => sub {
        my $val = shift;
        return "ERROR: multiplex_ssh value of $val is invalid.  Must be 0 for false, 1 for true"
          unless $val == 0 or $val == 1;
        return undef;
      },
      _example => 1
    },
    multiplex_control_persist_time => {
      _doc => <<DOC,
The (optional) multiplex_control_persist_time ssh option lets you configure how
long to persist the multiplex or Master Control Socket file 
DOC
      _default => 10, # 10 Min
      _re => '\d+',
      _sub => sub {
        my $val = shift;
        return "ERROR: multiplex_control_persist_time value of $val is invalid.  Must be >= 1 and <= 1000"
          unless $val >= 1 and $val <= 1000;
        return undef;
      },
      _example => "10"
    },
    multiplex_control_socket_path => {
      _doc => <<DOC,
The (optional) multiplex_control_persist_time ssh option lets you configure how
long to persist the multiplex or Master Control Socket file 
DOC
      _default => "~/.libnet-openssh-perl",
      _example => "/tmp/smokeping_ssh_sockets"
    }
  };

  return $class->_makevars($h, $params);
}

1;