# memperf metrics tests

This section includes metrics tests that measure memory performance.
Note, this is different from measuring the memory density (size). These
tests measure memory speed.

- `sysbench_memory.sh`: Logs the `sysbench memory` bandwidth result.
   Uses the default sysbench settings, which is to do 100G of memory writes
   sequentially in 1K blocks, single threaded.
