# Clear Containers remote networking test

- The`remote-networking-iperf3.sh` script measures bandwidth, jitter, latency, packet loss, or parallel bandwidth using
`iperf3`using a remote setup. Host A will run a container that will act as a server while host B will run a
container that will act as a client. The network bandwidth will be measured across the containers.

- The `remote-networking-memory-smem.sh` script measures RSS and PSS memory with the `smem` tool. Simultaneously,
the script uses a remote setup to run a bandwidth network test.

- The `remote-networking-cpu.sh` script measures the percentage of CPU consumption used while running
the maximum network bandwidth with `iperf3`.

- The `remote-networking-qperf.sh` script measures TCP and UDP latency with the `qperf` tool.

- The `direct-remote-networking-iperf3.sh` script measures bandwidth using a remote setup without using Swarm.
Host A runs an `iperf3` server container while host B runs `iperf3` client container.

`remote-networking-iperf3.sh`, `remote-networking-memory-smem.sh`, `remote-networking-cpu.sh`, and
`remote-networking-qperf.sh` use Swarm to run the client and the server containers.

## Prerequisite

An automatic login from host A (user A) to host B (user B) is needed. You must setup authentication 
keys to do an ssh login without password.
The following scripts are only compatible with `docker 1.12.1`:

- `remote-networking-cpu.sh`
- `remote-networking-iperf3.sh`
- `remote-networking-memory-smem.sh`
- `remote-networking-qperf.sh`

## Running the `remote-networking-iperf3.sh` test

`remote-networking-iperf3.sh` should run in host A. The script needs the following inputs to run:
- Arguments of the test to run. In this case the arguments are `-b` for bandwidth, `-j` for jitter,
`-l` for latency, `-p` for parallel bandwidth and `-t` to run all the tests.
- Use `-i` to specify the name of the interface where the swarm will run.
- Use `-u` to specify the username of host B.
- Use `-a` to specify the IP address of host B.

Use the following commands to run the `remote-networking-iperf3.sh` test manually:

```
$ cd metrics/network/remote_network
$ bash remote-networking-iperf3.sh "[options]" -i "<interface_name>" -u "<user>" -a "<ip_address>"

```

This is an example of how to run this script:

```
$ cd metrics/network/remote_network
$ bash remote-networking-iperf3.sh -b -i eno1 -u tester -a 10.xxx.xxx.xxx

```

## Running the `remote-networking-memory-smem.sh` test

`remote-networking-memory-smem.sh` script should run in host A. The script needs the following inputs to run:
- Arguments of the test to run. In this case the argument is `-r` for RSS memory. Use `-r` option for RSS memory.
- Use `-i` to specify the name of the interface where the swarm will run.
- Use `-u` to specify the username of host B.
- Use `-a` to specify the IP address of host B.

Use the following commands to run the `remote-networking-memory-smem.sh` test manually:

```
$ cd metrics/network/remote_network
$ bash remote-networking-memory-smem.sh "[options]" -i "<interface_name>" -u "<user>" -a "<ip_address>"

```
## Running the `remote-networking-cpu.sh` test

Run the `remote-networking-cpu.sh` script in host A. The script needs the following inputs to run:
- Use `-i` to specify the name of the interface where the Swarm will run.
- Use `-u` to specify the username of host B.
- Use `-a` to specify the IP address of host B.

Use the following commands to run the `remote-networking-cpu.sh` test manually:

```
$ cd metrics/network/remote_network
$ bash remote-networking-cpu.sh -i "<interface_name>" -u "<user>" -a "<ip_address>"

```
## Running the `remote-networking-qperf.sh` test

Run the `remote-networking-qperf.sh` script in host A. The script requires a number of options to
be specified. Run `remote-networking-qperf.sh` -h for details.

```
## Running the `direct-remote-networking-iperf3.sh` test

Run the `direct-remote-networking-iperf3.sh` script in host A. The script requires you to specify a number of options. Run
`direct-remote-networking-iperf3.sh` -h for details.

```
