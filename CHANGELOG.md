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