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
# Test inter-container network bandwidth and jitter using iperf3

SCRIPT_PATH=$(dirname "$(readlink -f "$0")")

source "${SCRIPT_PATH}/lib/network-test-common.bash"

# Port number where the server will run
port=5201:5201
# Image name
image=gabyct/network
# Measurement time (seconds)
time=5
# Name of the containers
server_name="network-server"
client_name="network-client"
# Arguments to run the client
extra_args="-ti --rm"

set -e

## Test name for reporting purposes
test_name="network metrics iperf3"

# This script will perform all the measurements using a local setup using iperf3

# Test single direction TCP bandwith
function iperf3_bandwidth {
	setup
	local server_command="mount -t ramfs -o size=20M ramfs /tmp && iperf3 -p ${port} -s"
	local server_address=$(start_server "$server_name" "$image" "$server_command")

	local client_command="mount -t ramfs -o size=20M ramfs /tmp && iperf3 -c ${server_address} -t ${time}"
	start_client "$extra_args" "$client_name" "$image" "$client_command" > "$result"

	local result_line=$(grep -m1 -E '\breceiver\b' $result)
	local -a results
	read -a results <<< $result_line
	local total_bandwidth=${results[6]}
	local total_bandwidth_units=${results[7]}
	echo "Network bandwidth is : $total_bandwidth $total_bandwidth_units"

	save_results "${test_name}" "network bandwidth" \
		"$total_bandwidth" "$total_bandwidth_units"

	clean_environment "$server_name"
}

# Test jitter on single direction UDP
function iperf3_jitter {
	setup
	local server_command="mount -t ramfs -o size=20M ramfs /tmp && iperf3 -s -V"
	local server_address=$(start_server "$server_name" "$image" "$server_command")

	local client_command="mount -t ramfs -o size=20M ramfs /tmp && iperf3 -c ${server_address} -u -t ${time}"
	start_client "$extra_args" "$client_name" "$image" "$client_command" > "$result"

	local result_line=$(grep -m1 -A1 -E '\bJitter\b' $result | tail -1)
	local -a results
	read -a results <<< $result_line
	local total_jitter=${results[8]}
	local total_jitter_units=${results[9]}
	echo "Network jitter is : $total_jitter $total_jitter_units"

	save_results "${test_name}" "network jitter" \
		"$total_jitter" "$total_jitter_units"

	clean_environment "$server_name"
}

# Run bi-directional TCP test, and extract results for both directions
function iperf3_bidirectional_bandwidth_client_server {
	setup
	local server_command="mount -t ramfs -o size=20M ramfs /tmp && iperf3 -p ${port} -s"
	local server_address=$(start_server "$server_name" "$image" "$server_command")

	local client_command="mount -t ramfs -o size=20M ramfs /tmp && iperf3 -c ${server_address} -d -t ${time}"
	start_client "$extra_args" "$client_name" "$image" "$client_command" > "$result"

	local client_result=$(grep -m1 -E '\breceiver\b' $result)
	local server_result=$(grep -m1 -E '\bsender\b'   $result)
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
	save_results "${test_name}" "network bidir bw server to client" \
		"$total_bidirectional_server_bandwidth" \
		"$total_bidirectional_server_bandwidth_units"

	clean_environment "$server_name"
}

echo "Currently this script is using ramfs for tmp (see https://github.com/01org/cc-oci-runtime/issues/152)"

iperf3_bandwidth

iperf3_jitter

iperf3_bidirectional_bandwidth_client_server
