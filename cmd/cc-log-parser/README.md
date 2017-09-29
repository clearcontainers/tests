# `cc-log-parser`

`cc-log-parser` is a tool that combines log files from various Clear
Containers components. It sorts the logfiles by timestamp and re-displays
them, adding a time delta showing how much time has elapsed between each log
entry.

## Component logfiles

The primary logfiles the tool reads are:

- The [runtime global log](https://github.com/clearcontainers/runtime#debugging).
- The [proxy log](https://github.com/clearcontainers/proxy#debugging), which
  comes from the system log.
- The shim log, which comes from the system log.

The [virtcontainers](https://github.com/containers/virtcontainers) logs are
automatically added to the runtimes global log.

The [agent](https://github.com/clearcontainers/agent) logs are encoded inside
the proxies log. The `cc-log-parser` tool automatically unpacks these and
displays only the agent log for these messages (the proxy message that
encapsulates an agent message is discarded).

## Usage

To merge together all logs:

1. [Enable global logging](https://github.com/clearcontainers/runtime#debugging) in the runtime configuration file.
1. [Enable shim debug output](https://github.com/clearcontainers/runtime#debugging) in the configuration file.
1. [Enable debug logging](https://github.com/clearcontainers/proxy#debugging) for the proxy.
1. Clear the systemd journal (optional):
   ```
   $ sudo systemctl stop systemd-journald
   $ sudo rm -f /var/log/journal/*/* /run/log/journal/*/*
   $ sudo systemctl start systemd-journald   
   ```
1. Create a container.
1. Collect the logs.
    1. Save the proxy log (which also includes agent log details):
       ```
       $ sudo journalctl -q -o cat -a -u cc-proxy |grep time= > ./proxy.log
       ```
    1. Save the shim log:
       ```
       $ sudo journalctl -q -o cat -a -t cc-shim > ./shim.log
       ```
    1. Save the runtime log:
       ```
       $ sudo cp /var/lib/clear-containers/runtime/runtime.log ./runtime.log
       ```
1. Ensure the logs are readable:
   ```
   $ sudo chown $USER *.log
   ```
1. Run the script:
   ```
   $ cc-log-parser proxy.log shim.log runtime.log
   ```
