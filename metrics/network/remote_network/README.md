# Clear Containers remote networking test

- The`remote-networking-iperf3.sh` script measures bandwidth using `iperf3` using a remote setup. Host A will run 
a container that will act as a server while host B will run a container that will act as a client. 
The network bandwidth will be measured across the containers.

## Prerequisite

An automatic login from host A (user A) to host B (user B) is needed. You must setup authentication 
keys to do an ssh login without password.

## Running the remote networking test

`remote-networking-iperf3.sh` should run in host A. The script needs the following inputs to run:
- Argument of the test to run. In this case this argument is `-b`.
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
