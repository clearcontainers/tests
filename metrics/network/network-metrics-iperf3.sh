#!/bin/bash

#  Copyright (C) 2017 Intel Corporation
#
#  This program is free software; you can redistribute it and/or
#  modify it under the terms of the GNU General Public License
#  as published by the Free Software Foundation; either version 2
#  of the License, or (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# This test measures the following network essentials:
# - bandwith simplex
# - bandwith duplex
# - jitter
#
# These metrics/results will be got from the interconnection between a container
# server and client using the iperf tool.
# container-server <----> container-client

set -e

SCRIPT_PATH=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_PATH}/lib/network-common.bash"
source "${SCRIPT_PATH}/../lib/common.bash"

TEST_NAME="iperf3 tests"

# Port number where the server will run
port="5201:5201"
# Image name
image="gabyct/network"
# Measurement time (seconds)
transmit_timeout=5
# Arguments to run the client/server
# "privileged" argument enables access to all devices on
# the host and it allows to avoid conflicts with AppArmor
# or SELinux configurations.
client_extra_args="-ti --privileged --rm"
server_extra_args="--privileged"

# Test single direction TCP bandwith
function iperf3_bandwidth() {
	local test_name="network iperf bandwidth"
	local server_command="mount -t ramfs -o size=20M ramfs /tmp && iperf3 -p ${port} -s"
	local server_address=$(start_server "$image" "$server_command" "$server_extra_args")

	# Verify server IP address
	if [ -z "$server_address" ];then
		clean_env
		die "server: ip address no found"
	fi

	local client_command="mount -t ramfs -o size=20M ramfs /tmp && iperf3 -c ${server_address} -t ${transmit_timeout}"
	result=$(start_client "$image" "$client_command" "$client_extra_args")

	local result_line=$(echo "$result" | grep -m1 -E '\breceiver\b')
	local -a results
	read -a results <<< $result_line
	local total_bandwidth=${results[6]}
	local total_bandwidth_units=${results[7]}
	echo "Network bandwidth is : $total_bandwidth $total_bandwidth_units"

	save_results "${test_name}" "network bandwidth" \
		"$total_bandwidth" "$total_bandwidth_units"
	clean_env
	echo "Finish"
}

# Test jitter on single direction UDP
function iperf3_jitter() {
	local test_name="network iperf jitter"
	local server_command="mount -t ramfs -o size=20M ramfs /tmp && iperf3 -s -V"
	local server_address=$(start_server "$image" "$server_command" "$server_extra_args")

	# Verify server IP address
	if [ -z "$server_address" ];then
		clean_env
		die "server: ip address no found"
	fi

	local client_command="mount -t ramfs -o size=20M ramfs /tmp && iperf3 -c ${server_address} -u -t ${transmit_timeout}"
	result=$(start_client "$image" "$client_command" "$client_extra_args")

	local result_line=$(echo "$result" | grep -m1 -A1 -E '\bJitter\b' | tail -1)
	local -a results
	read -a results <<< $result_line
	local total_jitter=${results[8]}
	local total_jitter_units=${results[9]}
	echo "Network jitter is : $total_jitter $total_jitter_units"

	save_results "${test_name}" "network jitter" \
		"$total_jitter" "$total_jitter_units"
	clean_env
	echo "Finish"
}

# Run bi-directional TCP test, and extract results for both directions
function iperf3_bidirectional_bandwidth_client_server() {
	local test_name="network iperf client to server"
	local server_command="mount -t ramfs -o size=20M ramfs /tmp && iperf3 -p ${port} -s"
	local server_address=$(start_server "$image" "$server_command" "$server_extra_args")

	# Verify server IP address
	if [ -z "$server_address" ];then
		clean_env
		die "server: ip address no found"
	fi

	local client_command="mount -t ramfs -o size=20M ramfs /tmp && iperf3 -c ${server_address} -d -t ${transmit_timeout}"
	result=$(start_client "$image" "$client_command" "$client_extra_args")

	local client_result=$(echo "$result" | grep -m1 -E '\breceiver\b')
	local server_result=$(echo "$result" | grep -m1 -E '\bsender\b')
	local -a client_results
	read -a client_results <<< ${client_result}
	read -a server_results <<< ${server_result}
	local total_bidirectional_client_bandwidth=${client_results[6]}
	local total_bidirectional_client_bandwidth_units=${client_results[7]}
	local total_bidirectional_server_bandwidth=${server_results[6]}
	local total_bidirectional_server_bandwidth_units=${server_results[7]}
	echo "Network bidirectional bandwidth (client to server) is :" \
		"$total_bidirectional_client_bandwidth" \
		"$total_bidirectional_client_bandwidth_units"
	echo "Network bidirectional bandwidth (server to client) is :" \
		"$total_bidirectional_server_bandwidth" \
		"$total_bidirectional_server_bandwidth_units"

	save_results "${test_name}" "network bidir bw client to server" \
		"$total_bidirectional_client_bandwidth" \
		"$total_bidirectional_client_bandwidth_units"

	# Save results in different files
	test_name="network iperf server to client"

	save_results "${test_name}" "network bidir bw server to client" \
		"$total_bidirectional_server_bandwidth" \
		"$total_bidirectional_server_bandwidth_units"
	clean_env
	echo "Finish"
}

init_env

echo "Currently this script is using ramfs for tmp (see https://github.com/01org/cc-oci-runtime/issues/152)"

iperf3_bandwidth

iperf3_jitter

iperf3_bidirectional_bandwidth_client_server
