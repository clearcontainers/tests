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
	Options:
		-h	Shows help
		-t	Run TCP latency
		-d	Run UDP latency
		-l	Run all latency tests
		-i	Interface name to run Swarm (mandatory)
		-u	User of host B (mandatory)
		-a	IP address of host B (mandatory)

EOF
)"
}

# This function will start an qperf server
function start_qperf_server {
	ssh "$ssh_user"@"$ssh_address" 'DOCKER_EXE=docker; \
			server_id=$($DOCKER_EXE ps -q); \
			server_command="qperf"; \
			$DOCKER_EXE exec -d "$server_id" sh -c "$server_command"'
}

# This function will measure the TCP latency using qperf
function remote_TCP_latency_qperf {
	setup_swarm
	client_replica_status
	server_replica_status

	server_ip_address=$(check_server_address)
	start_qperf_server

	client_id=$($DOCKER_EXE ps -q)
	client_command="qperf $server_ip_address tcp_lat conf"
	result=$(start_client "$client_id" "$client_command")
	total_latency=$(echo "$result" | grep latency | cut -f2 -d '=')
	echo "TCP Latency is : $total_latency"

	clean_environment
}

# This function will measure the UDP latency using qperf
function remote_UDP_latency_qperf {
	setup_swarm
	client_replica_status
	server_replica_status

	server_ip_address=$(check_server_address)
	start_qperf_server

	client_id=$($DOCKER_EXE ps -q)
	client_command="qperf $server_ip_address udp_lat quit"
	result=$(start_client "$client_id" "$client_command")
	total_latency=$(echo "$result" | grep latency | cut -f2 -d '=')
	echo "UDP Latency is : $total_latency"

	clean_environment
}


function main {
	local OPTIND
	while getopts "htdl:i:u:a" opt
	do
		case "${opt}" in
		h)
			help
			exit 0;
		;;
		t)
			tcp_latency_test="1"
			remote_TCP_latency_qperf
		;;
		d)
			udp_latency_test="1"
			remote_UDP_latency_qperf
		;;
		l)
			all_latency_tests="1"
			remote_TCP_latency_qperf
			remote_UDP_latency_qperf
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
