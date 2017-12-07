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

# This script will measure TCP and UDP network latency with qperf tool using a
# remote setup, where host A will run a server container and host B
# will run a client container.

set -e

SCRIPT_PATH=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_PATH}/remote-networking-test-common.sh"

# Extra args for the client
extra_args="-ti"

# This function describes how to use this script
function help {
echo "$(cat << EOF
Usage: $0 "[options]"
	Description:
		This script will measure network TCP and UDP latency with qperf tool
		using a remote setup, where host A will run a server container
		and host B will run a client container.
		In order to run this script, these inputs are needed:
		- Interface name where swarm will run.
		- User of the host B.
		- IP address of the host B
		This is an example of how to run this script:
		./remote-networking-qperf.sh [options] -i <interface_name> -u <user> -a <ip_address>
	Options:
		-a	IP address of host B (mandatory)
		-d	Run UDP latency
		-h	Shows help
		-i	Interface name to run Swarm (mandatory)
		-l	Run all latency tests
		-t	Run TCP latency
		-u	User of host B (mandatory)
EOF
)"
}

# This function will start an qperf server
function start_qperf_server {
	get_runtime
	ssh "$ssh_user"@"$ssh_address" 'DOCKER_EXE=docker; \
			server_id=$($DOCKER_EXE ps -q); \
			server_command="qperf"; \
			$DOCKER_EXE exec -d "$server_id" sh -c "$server_command"'
}

# This function will measure the TCP latency using qperf
function remote_TCP_latency_qperf {
	test_name="TCP latency qperf"
	get_runtime
	init_env
	init_env_remote
	setup_swarm
	client_replica_status
	server_replica_status

	server_ip_address=$(check_server_address)
	start_qperf_server

	client_id=$($DOCKER_EXE ps -q)
	client_command="qperf $server_ip_address tcp_lat conf"
	result=$(start_client "$extra_args" "$client_id" "$client_command")
	total_latency=$(echo "$result" | grep latency | cut -f2 -d '=' | awk '{print $1}')
	units=$(echo "$result" | grep latency | cut -f2 -d '=' | awk '{print $2}' | tr -d '\r')
	echo "TCP Latency is : $total_latency $units"

	save_results "$test_name" "TCP latency" "$total_latency" "$units"
	clean_environment
}

# This function will measure the UDP latency using qperf
function remote_UDP_latency_qperf {
	test_name="UDP latency qperf"
	get_runtime
	setup_swarm
	client_replica_status
	server_replica_status

	server_ip_address=$(check_server_address)
	start_qperf_server

	client_id=$($DOCKER_EXE ps -q)
	client_command="qperf $server_ip_address udp_lat quit"
	result=$(start_client "$extra_args" "$client_id" "$client_command")
	total_latency=$(echo "$result" | grep latency | cut -f2 -d '=' | awk '{print $1}')
	units=$(echo "$result" | grep latency | cut -f2 -d '=' | awk '{print $2}' | tr -d '\r')
	echo "UDP Latency is : $total_latency $units"

	save_results "$test_name" "UDP latency" "$total_latency" "$units"
	clean_environment
}


function main {
	local OPTIND
	while getopts ":a:dhlti:u:" opt
	do
		case "$opt" in
		a)
			ssh_address="$OPTARG"
			;;
		d)
			test_udp="1"
			;;
		h)
			help
			exit 0;
			;;
		i)
			interface_name="$OPTARG"
			;;
		l)
			test_total="1"
			;;
		t)
			test_tcp="1"
			;;
		u)
			ssh_user="$OPTARG"
			;;
		\?)
			echo "An invalid option has been entered: -$OPTARG";
			help
			exit 1;
			;;
		:)
			echo "Missing argument for -$OPTARG";
			help
			exit 1;
			;;
		esac
	done
	shift $((OPTIND-1))

	[[ -z "$interface_name" ]] && help && die "Missing Swarm Interface."
	[[ -z "$ssh_address" ]] && help && die "Missing IP Address."
	[[ -z "$ssh_user" ]] && help && die "Missing User."

	if [ "$test_tcp" == "1" ]; then
		remote_TCP_latency_qperf
	elif [ "$test_udp" == "1" ]; then
		remote_UDP_latency_qperf
	elif [ "$test_total" == "1" ]; then
		remote_TCP_latency_qperf
		remote_UDP_latency_qperf
	else
		exit 0
	fi
}
main "$@"
