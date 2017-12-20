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

# This script measures network bandwidth with iperf3 tool using a remote
# setup without using Swarm, where host A will run directly an iperf3
# server container and host B will run an iperf3 client container.

set -e

SCRIPT_PATH=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_PATH}/remote-networking-test-common.sh"

# Time to run the server using iperf3
server_time="30"

# This function describes how to use this script
function help {
echo "$(cat << EOF
Usage: $0 "[options]"
	Description:
		This script measures network bandwidth or parallel bandwidth with
		an iperf3 container using a remote setup without using Swarm, where host A
		will run a server container and host B will run a client container.
		In order to run this script, these inputs are needed:
		- User of the host B.
		- IP address of the host B.
		This is an example of how to run this script:
		./direct-remote-networking-iperf3.sh [options] -a <ip_address> -u <user>
	Options:
		-a	IP address of host B (mandatory)
		-b	Run remote bandwidth
		-h	Shows help
		-u	User of host B (mandatory)
EOF
)"
}

# This function measures bandwidth using iperf3
function direct_remote_network_bandwidth_iperf3 {
	test_name="Direct Remote Bandwidth"
	check_images "$network_image"
	direct_start_server

	client_command="iperf3 -c $ssh_address -t $server_time"
	result=$(direct_start_client "$client_command")
	total_bandwidth=$(echo "$result" | tail -n 3 | head -1 | awk '{print $(NF-2)}')
	units=$(echo "$result" | tail -n 3 | head -1 | awk '{print $(NF-1)}')
	echo "Network bandwidth is : $total_bandwidth $units"

	save_results "$test_name" "Direct bandwidth" "$total_bandwidth" "$units"
	clean_direct_environment
}

function main {
	local OPTIND
	while getopts ":a:bh:u:" opt
	do
		case "$opt" in
		a)
			ssh_address="$OPTARG"
			;;

		b)
			direct_bandwidth_test="1"
			;;
		h)
			help
			exit 0;
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

	[[ -z "$ssh_address" ]] && help && die "Missing IP Address."
	[[ -z "$ssh_user" ]] && help && die "Missing User."

	if [ "$direct_bandwidth_test" == "1" ]; then
		direct_remote_network_bandwidth_iperf3
	else
		exit 0
	fi
}
main "$@"
