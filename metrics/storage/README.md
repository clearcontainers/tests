# Storage metrics tests

This section includes metrics tests that measure storage bandwith under different
conditions/configuration. These tests can be executed with different I/O operations
such as: read, write, random read, etc.
However, in order to find the hot spot, these tests should be used in combination
with more tools.

- `fio_job.sh`: measures the I/O bandwidth using a specific storage operation (read, write,
   random-read, etc) under a default configuration. The default operations and
   configuration can be overwritten.
