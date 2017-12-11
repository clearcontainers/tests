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

# This script will measure RSS memory with smem tool while running an iperf3
# bandwidth network measurement using a remote setup, where host A will run a
# server container and host B will run a client container.

set -e

SCRIPT_PATH=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_PATH}/remote-networking-test-common.sh"

# Set QEMU_PATH unless it's already set
QEMU_PATH=${QEMU_PATH:-$(get_qemu_path)}
# Time in which we sample the memory (seconds)
middle_time=10
# Time to run the server using iperf3 (seconds)
server_time=30
# Arguments to run the client
extra_args="-d"

# This function describes how to use this script
function help {
echo "$(cat << EOF
Usage: $0 "[options]"
	Description:
		This script measures RSS memory using smem tool. Simultaneously, the script
		runs a server container and host B runs a client container.
		To run this script, provide the following inputs:
		- Interface name where swarm will run.
		- User of the host B.
		- IP address of the host B
		This is an example of how to run this script:
		./remote-networking-memory-smem.sh [options] -i <interface_name> -u <user> -a <ip_address>
	Options:
		-a	IP address of host B (mandatory)
		-h	Shows help
		-i	Interface name to run Swarm (mandatory)
		-r	Run RSS memory
		-u	User of host B (mandatory)
EOF
)"
}

# This function will measure RSS memory with smem tool
function remote_network_rss_memory {
	test_name="Remote Network RSS Memory"
	units="Kb"
	get_runtime
	setup_swarm
	client_replica_status
	server_replica_status

	server_ip_address=$(check_server_address)
	start_server

	client_id=$($DOCKER_EXE ps -q)
	command="iperf3 -c $server_ip_address -t $server_time"
	check_iperf3_client_command "$command"
	start_client "$extra_args" "$client_id" "$client_command" > /dev/null

	# Time when we are taking our RSS measurement
	echo >&2 "WARNING: Sleeping for $middle_time seconds to sample the RSS memory."
	sleep ${middle_time}

	if [ "$runtime_client" == "runc" ]; then
		process="iperf"
	elif [ "$runtime_client" == "cc-runtime" ]; then
		process="$QEMU_PATH"
	else
		die "Unknown client runtime: $runtime_client."
	fi
	memory_command="sudo smem --no-header -c rss"
	result=$(${memory_command} -P ^${process})

	memory=$(echo "$result" | awk '{ total += $1 } END { print total/NR }')
	echo "RSS Memory is : $memory $units"
	save_results "$test_name" "RSS memory" "$memory" "$units"

	clean_environment
}

function main {
	local OPTIND
	while getopts ":a:hri:u:" opt
	do
		case "$opt" in
		a)
			ssh_address="$OPTARG"
			;;
		h)
			help
			exit 0;
			;;
		i)
			interface_name="$OPTARG"
			;;
		r)
			test_rss="1"
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

	if [ "$test_rss" == "1" ]; then
		remote_network_rss_memory
	else
		exit 0
	fi
}
main "$@"
