# Density metrics tests

This section includes metrics tests that measure the amount of memory used by
a determined number of containers or a specific process that is part of the flow.
This number of containers could be working under different configurations/conditions.

- `docker_memory_usage.sh`: measures the Proportional Set Size (PSS) memory average
   for a number of containers launched in idle mode. This test uses the `sleep` command
   to allow any memory optimizations to 'settle' (e.g. KSM execution) for a configurable
   period of time. It also has an optional 'auto' mode which will try to determine when KSM
   has settled down by examining the KSM `full_scans` and `pages_shared` values. auto mode
   detection of KSM settling over-rides the timeout value for taking the measurements and
   completing the test.
- `docker_memory_usage.sh`: measures the Proportional Set Size (PSS) memory average
   for a number of containers launched in idle mode. 
   The test has two methods that can be utilized to wait for `KSM` to 'settle'.
    - The test sleeps for the amount of time specified by the 'timeout', which is
      in seconds, before taking measurements.
    - If `auto` mode is enabled, the test terminates `timeout` early
      under the condition that 'KSM' has already settled, which
      is determined by exmaining the `KSM` `full_scans` and `pages_shared`
      information.

- `footprint_data.sh`: Sequentially runs a number of identical containers and takes a
   number of memory related measurements after each launch. Generally not used in a CI
   type environment, but more for hand run/analysis. Refer to the
   [footprint_data.md](footprint_data.md) file for more details.
