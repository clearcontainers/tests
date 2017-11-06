# Time metrics tests

This section includes metrics tests that measure the time interval[s] of a determined
number of containers executing a defined workload. This kind of metrics tests could provide
a general overview about the time spent by a flow, however in order to find the hot spot,
these tests should be used in combination with more tools.

- `docker_workload_time.sh`: measures the time taken for a container using Docker to complete
   a workload. In this test, the workload is to execute a true. By using this workload, the
   test does not add overhead when measuring the container flow execution time.
- `launch_times.sh`: measures the time it takes to get through a number of the boot and
   execution 'round trip' times, using a combination of `date` and `dmesg` on the host
   and in the container. Can measure either for the first container launched, or as a
   scaling test, launching a permanently running container between each measurement.
   Can also measure with the docker networking disabled.
