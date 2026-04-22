# RELEASE NOTES
## Changelog
### Version 1.4.1
- Added support for TTL - Time to Live
- Added support for Interface Name
- Added support for DSCP ID
- Added support for Do Not Fragment flag
- Added support for finer grained debugging of Multiplexed SSH Connections
- Fixed issue where rtable option not working
### Version 1.4.2
- Fixed issue where enabling debug_ssh caused probe to return to caller before
  completing ssh connection and command
### Version 1.4.3
- Fixed issue where if control socket path does not exist it would fail to be
  created if debug = true was not set on target
- Corrected documentation referring to Target Host SSH Port, should be Source
  SSH POrt
### Version 1.4.4
- Fixed issue where replies with a non-empty STATUS column (e.g. "host
  unreachable" returned by an intermediate hop) were counted as successful
  pings. The time regex is now anchored to end-of-line so only replies with
  an empty STATUS column are recorded; anything else is treated as a dropped
  packet, matching MikroTik's own packet-loss accounting.
### Version 1.4.5
- Added ssh_connect_timeout target var (default 10s) mapped to OpenSSH's
  -oConnectTimeout. Unreachable routers now fail within a few seconds
  instead of blocking the probe for the full session timeout.
- Added ssh_timeout target var (default 60s) exposing the Net::OpenSSH
  master-channel timeout that was previously hardcoded.
- Added ssh_strict_host_key_checking target var (default accept-new)
  replacing the previous hardcoded StrictHostKeyChecking=no behaviour
  that only applied in the multiplex branch. The new default auto-adds
  host keys on first connect but fails loud on key changes. Applied
  consistently whether multiplexing is enabled or not.
- Net::OpenSSH now invoked with kill_ssh_on_timeout=1 so timed-out ssh
  subprocesses are cleaned up rather than lingering.
- Removed a stray closing brace in the multiplex-new-master branch that
  had been introduced in commit dce8918 and prevented the .pm from
  loading under Perl. This fix is a side-effect of the master_opts
  restructure.
### Version 1.4.6
- Added ssh_key_path target var for SSH key-based authentication. When
  set, the ssh client is invoked with -i <path> and routerospass is
  bypassed.
- routerospass is now optional (removed from the _mandatory list).
  Targets may authenticate via routerospass, ssh_key_path, or by leaving
  both unset and relying on ssh-agent / default identity files (useful
  for containerised smokeping deployments that mount SSH_AUTH_SOCK).
- README documents the full MikroTik-side setup (ssh-keygen, scp, /user
  ssh-keys import) and shows all three auth modes in the target
  examples.
### Version 1.4.7
- Fixed two separate "Invalid or bad combination of options ..." errors
  from Net::OpenSSH introduced by the 1.4.6 auth changes:
  1. "(22, key_path, 60, 1, 0)" when routerospass was unset.  The %opts
     hash was using the "key" => ($val ? $val : ()) idiom, which
     flattens to a bare "key" (no value) when $val is falsy, producing
     an odd-element list that pairs subsequent keys and values into the
     wrong slots.  Replaced with ($val ? (key => $val) : ()) so the
     whole pair is added or omitted atomically.
  2. "(key_path)" when a target with ssh_key_path set inherited
     routerospass from the probe-level default.  Net::OpenSSH refuses
     key_path and password in the same call.  Now ssh_key_path takes
     precedence over routerospass so targets can flip individual
     entries to key auth without unsetting the probe-level default.
### Version 1.4.8
- debug=true output now starts with a one-line cycle-start summary
  (host, dest, user, auth method, multiplex, timeouts, strict-host-key
  policy) and ends with a cycle-done summary including phase timings
  (connect / command / parse / total) and the parsed sample count.
  Makes "why is this probe slow?" answerable without enabling
  debug_ssh.
- debug=true now logs the full composed ssh invocation (ssh_binary_path
  + master_opts + -p port + user@host + quoted ping command).  Copy-
  paste this as the smokeping user to reproduce connection failures
  manually.
- The RouterOS "sent=N received=N packet-loss=N%" footer line is no
  longer silently discarded.  debug=true now logs it and cross-checks
  the router's received count against the parser's sample count,
  emitting a "WARN parser drift" line on mismatch.  Surfaces parser
  regressions against new RouterOS output formats.
- Documentation (POD, MANPAGE.md, README.md) now carries a prominent
  security warning that debug_logfile contains routerospass in
  plaintext (via the existing Net::OpenSSH options Dumper dump) and
  the on-disk path of ssh_key_path.  If you have previously run with
  debug=true, rotate or redact any historical debug_logfile files
  before sharing them externally.
- Fixed latent regression from 1.4.5: Net::OpenSSH forbids master_opts
  alongside external_master=1, so reusing an existing multiplex
  control socket would fail with "Invalid or bad combination of
  options ('master_opts')" once a socket persisted between probe
  cycles.  master_opts is now dropped from %opts on the socket-reuse
  path.  Fresh-master creation path is unchanged.