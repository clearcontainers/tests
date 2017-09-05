# PnP failure Report tool

This tool obtains metrics results from `checkmetrics` tool, and sends
the results out via email.
The configuration of SMTP server and `checkmetrics` tool arguments are
given by a configuration file in TOML format, a TOML configuration
file can be specified by command line or it is installed in
`/etc/emailreport/emailreport.toml` by default.

WARNING: The password for the SMTP authentication will be in TOML
configuration text plane file.

## Options
The `emailreport` tool takes a number of options.

### Add comments/suggestions in the message body
```
-c    comments/suggestions
```

### Specify the TOML configuration file by command line
```
-f    path to TOML configuration file
```

### Add/Overwrite email subject
```
-s    email subject
```

### Help
```
-h    show help
```

## Usage
```bash
$ ./emailreport [-f <conf.toml>] [-c <"comments">] [-s <"subject">]
```
