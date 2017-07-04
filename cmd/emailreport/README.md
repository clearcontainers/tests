# PnP failure Report tool

This tool obtains metrics results from `checkmetrics` tool, and sends
the results out via email.
The configuration of SMTP server and `checkmetrics` tool arguments are
given by a configuration file in TOML format, an example TOML configuration
file is provided in the file `example.toml`

WARNING: The password for the SMTP authentication will be in TOML
configuration text plane file.

# Usage
```bash
$ ./emailreport -f <conf.toml>
```
