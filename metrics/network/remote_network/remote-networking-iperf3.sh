#!/bin/bash

# Copyright (c) 2017 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# This script will measure network bandwidth, jitter or parallel bandwidth
# with iperf3 tool using a remote setup, where host A will run a server
# container and host B will run a client container.

set -e

SCRIPT_PATH=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_PATH}/remote-networking-test-common.sh"

# Time to run the server using iperf3
server_time=30

# This function describes how to use this script
function help {
echo "$(cat << EOF
Usage: $0 "[options]"
	Description:
		This script will measure network bandwidth, jitter and parallel
		bandwidth with iperf3 tool using a remote setup, where host A
		will run a server container and host B will run a client container.
		In order to run this script, these inputs are needed:
		- Interface name where swarm will run.
		- User of the host B.
		- IP address of the host B
	Options:
		-h	Shows help
		-b	Run remote bandwidth
		-j	Run remote jitter
		-p	Run parallel bandwidth (-P4)
		-t	Run remote bandwidth, jitter and parallel bandwidth
		-i	Interface name to run Swarm (mandatory)
		-u	User of host B (mandatory)
		-a	IP address of host B (mandatory)

EOF
)"
}

# This function will measure the bandwidth using iperf3
function remote_network_bandwidth_iperf3 {
	setup_swarm
	client_replica_status
	server_replica_status

	server_ip_address=$(check_server_address)
	start_server

	client_id=$($DOCKER_EXE ps -q)
	client_command="mount -t ramfs -o size=20M ramfs /tmp && iperf3 -c $server_ip_address -t $server_time"
	result=$(start_client "$client_id" "$client_command")
	total_bandwidth=$(echo "$result" | tail -n 3 | head -1 | awk '{print $(NF-2), $(NF-1)}')
	echo "Network bandwidth is : $total_bandwidth"

	clean_environment
}

# This function will measure the jitter using iperf3
function remote_network_jitter_iperf3 {
	setup_swarm
	client_replica_status
	server_replica_status

	server_ip_address=$(check_server_address)
	start_server

	client_id=$($DOCKER_EXE ps -q)
	client_command="mount -t ramfs -o size=20M ramfs /tmp && iperf3 -c $server_ip_address -u -t $server_time"
	result=$(start_client "$client_id" "$client_command")
	total_jitter=$(echo "$result" | tail -n 4 | head -1 | awk '{print $(NF-3), $(NF-2)}')
	echo "Network jitter is : $total_jitter"

	clean_environment
}

# This function will measure parallel bandwidth using iperf3
function remote_network_parallel_iperf3 {
	setup_swarm
	client_replica_status
	server_replica_status

	server_ip_address=$(check_server_address)
	start_server

	client_id=$($DOCKER_EXE ps -q)
	client_command="mount -t ramfs -o size=20M ramfs /tmp && iperf3 -c $server_ip_address -P4 -t $server_time"
	result=$(start_client "$client_id" "$client_command")
	total_parallel=$(echo "$result" | tail -n 4 | head -1 | awk '{print $(NF-3), $(NF-2)}')
	echo "Parallel network is : $total_parallel"

	clean_environment
}


function main {
	local OPTIND
	while getopts "hbjpt:i:u:a" opt
	do
		case "${opt}" in
		h)
			help
			exit 0;
		;;
		b)
			bandwidth_test="1"
			remote_network_bandwidth_iperf3
		;;
		j)
			jitter_test="1"
			remote_network_jitter_iperf3
		;;
		p)
			parallel_test="1"
			remote_network_parallel_iperf3
		;;
		t)
			total_test="1"
			remote_network_bandwidth_iperf3
			remote_network_jitter_iperf3
			remote_network_parallel_iperf3
		;;
		i)
			interface_name="${OPTARG}"
		;;
		u)
			ssh_user="${OPTARG}"
		;;
		a)
			ssh_address="${OPTARG}"
                ;;
		esac
		shift
	done
	shift $((OPTIND-1))

	[ -z "$ssh_address" ] && help && die "Mandatory IP address of host B not supplied"
	[ -z "$ssh_user" ] && help && die "Mandatory user of host B not supplied"
	[ -z "$interface_name" ] && help && die "Mandatory interface name to run Swarm not supplied"

}
main "$@"
