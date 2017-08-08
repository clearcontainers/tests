# PnP failure Report tool

This tool obtains metrics results from `checkmetrics` tool, and sends
the results out via email.
The configuration of SMTP server and `checkmetrics` tool arguments are
given by a configuration file in TOML format, a TOML configuration
file can be specified by command line or it is installed in
`/etc/emailreport/emailreport.toml` by default.

WARNING: The password for the SMTP authentication will be in TOML
configuration text plane file.

# Usage
```bash
$ ./emailreport [-f <conf.toml>]
```
