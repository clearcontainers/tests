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

# This script will measure network bandwidth, jitter, latency or parallel
# bandwidth with iperf3 tool using a remote setup, where host A will run a
# server container and host B will run a client container.

set -e

SCRIPT_PATH=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_PATH}/remote-networking-test-common.sh"

# Time to run the server using iperf3
server_time=30
# Arguments to run the client
extra_args="-ti"

# This function describes how to use this script
function help {
echo "$(cat << EOF
Usage: $0 "[options]"
	Description:
		This script will measure network bandwidth, jitter, latency and
		parallel bandwidth with iperf3 tool using a remote setup, where host A
		will run a server container and host B will run a client container.
		In order to run this script, these inputs are needed:
		- Interface name where swarm will run.
		- User of the host B.
		- IP address of the host B
		This is an example of how to run this script:
		./remote-networking-iperf3.sh [options] -i <interface_name> -u <user> -a <ip_address>
	Options:
		-a	IP address of host B (mandatory)
		-b	Run remote bandwidth
		-h	Shows help
		-i	Interface name to run Swarm (mandatory)
		-j	Run remote jitter
		-l	Run remote latency
		-p	Run remote parallel bandwidth (-P4)
		-t	Run all remote tests
		-u	User of host B (mandatory)
EOF
)"
}

# This function will measure the bandwidth using iperf3
function remote_network_bandwidth_iperf3 {
	test_name="Remote network bandwidth"
	get_runtime
	setup_swarm
	client_replica_status
	server_replica_status

	server_ip_address=$(check_server_address)
	start_server

	client_id=$($DOCKER_EXE ps -q)
	command="iperf3 -c $server_ip_address -t $server_time"
	check_iperf3_client_command "$command"
	result=$(start_client "$extra_args" "$client_id" "$client_command")
	total_bandwidth=$(echo "$result" | tail -n 3 | head -1 | awk '{print $(NF-2)}')
	units=$(echo "$result" | tail -n 3 | head -1 | awk '{print $(NF-1)}')
	echo "Network bandwidth is : $total_bandwidth $units"

	save_results "$test_name" "Remote Bandwidth" "$total_bandwidth" "$units"
	clean_environment
}

# This function will measure the jitter using iperf3
function remote_network_jitter_iperf3 {
	test_name="Remote network jitter"
	get_runtime
	setup_swarm
	client_replica_status
	server_replica_status

	server_ip_address=$(check_server_address)
	start_server

	client_id=$($DOCKER_EXE ps -q)
	command="iperf3 -c $server_ip_address -u -t $server_time"
	check_iperf3_client_command "$command"
	result=$(start_client "$extra_args" "$client_id" "$client_command")
	total_jitter=$(echo "$result" | tail -n 4 | head -1 | awk '{print $(NF-4)}')
	units=$(echo "$result" | tail -n 4 | head -1 | awk '{print $(NF-3)}')
	echo "Network jitter is : $total_jitter $units"

	save_results "$test_name" "Remote jitter" "$total_jitter" "$units"
	clean_environment
}

# This function will measure parallel bandwidth using iperf3
function remote_network_parallel_iperf3 {
	test_name="Remote network parallel bandwidth"
	get_runtime
	setup_swarm
	client_replica_status
	server_replica_status

	server_ip_address=$(check_server_address)
	start_server

	client_id=$($DOCKER_EXE ps -q)
	command="iperf3 -c $server_ip_address -P4 -t $server_time"
	check_iperf3_client_command "$command"
	result=$(start_client "$extra_args" "$client_id" "$client_command")
	total_parallel=$(echo "$result" | tail -n 4 | head -1 | awk '{print $(NF-3)}')
	units=$(echo "$result" | tail -n 4 | head -1 | awk '{print $(NF-2)}')
	echo "Parallel network is : $total_parallel $units"

	save_results "$test_name" "Remote parallel" "$total_parallel" "$units"
	clean_environment
}

# This function will measure latency across containers
function remote_network_latency {
	test_name="Remote network latency"
	get_runtime
	#Number of packages
	number_of_packages=10
	units="ms"
	setup_swarm
	client_replica_status
	server_replica_status

	server_ip_address=$(check_server_address)
	client_id=$($DOCKER_EXE ps -q)
	client_command="ping -c "$number_of_packages" "$server_ip_address""
	result=$(start_client "$extra_args" "$client_id" "$client_command")
	total_latency=$(echo $result | grep avg | awk '{print $(NF-1)}' | cut -d '/' -f 2)
	echo "Network latency is : $total_latency $units"

	save_results "$test_name" "Remote latency" "$total_latency" "$units"
	clean_environment
}

function main {
	[[ $# -ne 7 ]]&& help && die "Illegal number of parameters."

	local OPTIND
	while getopts ":a:bhjlpti:u:" opt
	do
		case "$opt" in
		a)
			ssh_address="$OPTARG"
			;;
		b)
			test_bandwidth="1"
			;;
		h)
			help
			exit 0;
                	;;
		i)
			interface_name="$OPTARG"
			;;
		j)
			test_jitter="1"
			;;
		l)
			test_latency="1"
			;;
		p)
			test_parallel="1"
			;;
		t)
			test_total="1"
			;;
		u)
			ssh_user="$OPTARG"
			;;
		\?)
			echo "An invalid option has been entered: -$OPTARG";
			help
			exit 0;
			;;
		:)
			echo "Missing argument for -$OPTARG";
			help
			exit 0;
			;;
		esac
	done
	shift $((OPTIND-1))

	[[ -z "$interface_name" ]] && help && die "Missing IP Address."
	[[ -z "$ssh_address" ]] && help && die "Missing Swarm Interface."
	[[ -z "$ssh_user" ]] && help && die "Missing User."

	if [ "$test_bandwidth" == "1" ]; then
		remote_network_bandwidth_iperf3
	elif [ "$test_jitter" == "1" ]; then
		remote_network_jitter_iperf3
	elif [ "$test_parallel" == "1" ]; then
		remote_network_parallel_iperf3
	elif [ "$test_latency" == "1" ]; then
		remote_network_latency
	elif [ "$test_total" == "1" ]; then
		remote_network_bandwidth_iperf3
		remote_network_jitter_iperf3
		remote_network_parallel_iperf3
		remote_network_latency
	else
		exit 0
	fi
}
main "$@"
