# Time metrics tests

This section includes metrics tests that measure the time interval[s] of a determined
number of containers executing a defined workload. This kind of metrics tests could provide
a general overview about the time spent by a flow, however in order to find the hot spot,
these tests should be used in combination with more tools.

- `docker_workload_time.sh`: measures the time taken for a container using Docker to complete
   a workload. In this test, the workload is to execute a true. By using this workload, the
   test does not add overhead when measuring the container flow execution time.
