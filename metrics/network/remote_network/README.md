# Clear Containers remote networking test

- The`remote-networking-iperf3.sh` script measures bandwidth, jitter, latency or parallel bandwidth using
`iperf3`using a remote setup. Host A will run a container that will act as a server while host B will run a
container that will act as a client. The network bandwidth will be measured across the containers.

## Prerequisite

An automatic login from host A (user A) to host B (user B) is needed. You must setup authentication 
keys to do an ssh login without password.
The `remote-networking-iperf3.sh` is only compatible with `docker 1.12.1`.

## Running the remote networking test

`remote-networking-iperf3.sh` should run in host A. The script needs the following inputs to run:
- Arguments of the test to run. In this case the arguments are `-b` for bandwidth, `-j` for jitter,
`-l` for latency, `-p` for parallel bandwidth and `-t` to run all the tests.
- Interface name where swarm will run.
- User of the host B.
- IP address of the host B.

The `remote-networking-iperf3.sh` test may be run manually:

```
$ cd metrics/network/remote_network
$ bash remote-networking-iperf3.sh "[options]" "<interface_name>" "<user>" "<ip_address>"

```

This is an example of how to run this script:

```
$ cd metrics/network/remote_network
$ bash remote-networking-iperf3.sh -b -i eno1 -u tester -a 10.xxx.xxx.xxx

```
