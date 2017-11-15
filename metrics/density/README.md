# Density metrics tests

This section includes metrics tests that measure the amount of memory used by
a determined number of containers or a specific process that is part of the flow.
This number of containers could be working under different configurations/conditions.

- `docker_memory_usage.sh`: measures the Proportional Set Size (PSS) memory average
   for a number of containers launched in idle mode. This test uses the `sleep` command
   to allow any memory optimizations to 'settle' (e.g. KSM execution) for a configurable
   period of time.
- `footprint_data.sh`: Sequentially runs a number of identical containers and takes a
   number of memory related measurements after each launch. Generally not used in a CI
   type environment, but more for hand run/analysis. Refer to the
   [footprint_data.md](footprint_data.md) file for more details.
