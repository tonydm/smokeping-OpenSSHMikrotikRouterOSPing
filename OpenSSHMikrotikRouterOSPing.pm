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

# Debugging
# use Data::Dumper;

my $e = "=";
sub pod_hash {
  return {
  name => <<DOC,
Smokeping::probes::OpenSSHMikrotikRouterOSPing - Mikrotik RouterOS SSH Probe for SmokePing
DOC
  description => <<DOC,
Connect to Mikrotik RouterOS Device via OpenSSH to run ping commands.
This probe uses the "ping" cli of the Mikrotik RouterOS.  You have
the option to specify which interface the ping is sourced from as well.
DOC
  notes => <<DOC,
${e}head2 Mikrotik RouterOS configuration

The Mikrotik RouterOS device should have a username/password configured, and
the ssh server must not be disabled.

Make sure to connect to the remote host once from the commmand line as the
user who is running smokeping. On the first connect ssh will ask to add the
new host to its known_hosts file. This will not happen automatically so the
script will fail to login until the ssh key of your Mikrotik RouterOS box is in the
known_hosts file.

${e}head2 Requirements

This module requires the  L<Net::OpenSSH> and L<IO::Pty> perl modules.
DOC
  authors => <<'DOC',
Tony DeMatteis E<lt>tonydema@gmail.comE<gt>

based on L<Smokeping::Probes::OpenSSHJunOSPing> by Tobias Oetiker E<lt>tobi@oetiker.chE<gt>,
which itself is
based on L<Smokeping::probes::TelnetJunOSPing> by S H A N E<lt>shanali@yahoo.comE<gt>.
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
  my $port = $target->{vars}{ssh_port};
  my $source = $target->{vars}{source};
  my $dest = $target->{vars}{host};
  my $psource = $target->{vars}{psource};
  my @output = ();
  my $login = $target->{vars}{routerosuser};
  my $password = $target->{vars}{routerospass};
  my $bytes = $self->{properties}{packetsize};
  my $pings = $self->pings($target);
  my $ssh_cmd = $target->{vars}{ssh_binary_path};

  # do NOT call superclass ... the ping method MUST be overwriten
  my %upd;
  my @args = ();

  # Note: To debug the SSH Connection modify the master_opts options to include ""-vvv"
  # master_opts => [-o => "StrictHostKeyChecking=no", "-vvv"],
  my $ssh = Net::OpenSSH->new(
    $source,
    $login ? ( user => $login ) : (),
    $password ? ( password => $password ) : (),
    port => $port,
    timeout => 60,
    strict_mode => 0,
    kill_ssh_on_timeout => 1,
    ctl_dir => "/tmp/.libnet-openssh-perl",
    master_opts => [-o => "StrictHostKeyChecking=no"],
    $ssh_cmd ? (ssh_cmd => $ssh_cmd) : (ssh_cmd => '/usr/bin/ssh')
  );

  if ($ssh->error) {
    $self->do_log( "OpenSSHMikrotikRouterOSPing connecting $source: ".$ssh->error );
    return ();
  };

  # Debug
  # $self->do_log("ping $dest count=$pings size=$bytes src-address=$psource");

  if ( $psource ) {
    @output = $ssh->capture("ping $dest count=$pings size=$bytes src-address=$psource");
  } else {
    @output = $ssh->capture("ping $dest count=$pings size=$bytes");
  }

  if ($ssh->error) {
    $self->do_log( "OpenSSHMikrotikRouterOSPing running commands on $source: ".$ssh->error );
    return ();
  };

  # Debug
  # $self->do_log(Dumper \@output);

  my @times = ();

  while (@output) {
    my $outputline = shift @output;
    chomp($outputline);
    next if ($outputline =~ m/(sent|recieved|packet\-loss|min\-rtt|avg\-rtt)/);
    $outputline =~ /(\d+)ms/ && push(@times,$1);
  }

  @times = map {sprintf "%.10e", $_ / $self->{pingfactor}} sort {$a <=> $b} @times;

  # Debug
  # $self->do_log(Dumper \@times);
  # my $length = @times;
  # $self->do_log("Length of times: $length");

  return @times;
}

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
  # Override defaults
  # Modify pings
  # Add ssh_port
  # Add ssh_binary_path
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
The routerosuser option allows you to specify a username that has ping
capability on the Mikrotik RouterOS Device.
DOC
      _example => 'user',
    },
    routerospass => {
      _doc => <<DOC,
The routerospass option allows you to specify the password for the username
specified with the option routerosuser.
DOC
      _example => 'password',
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
      _doc => 'Connect to this port.',
      _re => '\d+',
      _default => 22,
      _example => 22431,
    },
    ssh_binary_path => {
      _doc => <<DOC,
The ssh_binary_path option specifies the path for the ssh client binary.
This option will specify the path to the OpenSSH host connector.  It may be
necessary to define the path to the binary if it is not found.  To find the
path use "which ssh".
DOC
      _example => "/usr/bin/ssh",
    }
  };

  return $class->_makevars($h, $params);
}

1;
