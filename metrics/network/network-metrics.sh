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
# Description:
# This metrics test measures the network bandwidth using iperf2 in
# a interconnection container-client <----> container-server.

set -e

SCRIPT_PATH=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_PATH}/lib/network-common.bash"
source "${SCRIPT_PATH}/../lib/common.bash"

TEST_NAME="iperf2 tests"

# Extract bandwidth results for both directions from the one test
function bidirectional_bandwidth_server_client() {
	# Port number where the server will run
	local port="5001:5001"
	# Image name
	local image="gabyct/network"
	# Measurement time (seconds)
	local transmit_timeout=5

	# Arguments to run the client
	local extra_args="--rm"

	# Initialize/clean environment
	init_env
	check_images "$image"

	server_command="iperf -p ${port} -s"
	local server_address=$(start_server "$image" "$server_command")

	client_command="iperf -c ${server_address} -d -t ${transmit_timeout}"
	result="$(start_client "$image" "$client_command" "$extra_args")"

	local server_result=$(echo "$result" | tail -1)
	read -a server_results <<< ${server_result%$'\r'}
	local client_result=$(echo "$result" | tail -n 2 | head -1)
	read -a client_results <<< ${client_result%$'\r'}

	local total_bidirectional_server_bandwidth=${server_results[-2]}
	local total_bidirectional_server_bandwidth_units=${server_results[-1]}
	local total_bidirectional_client_bandwidth=${client_results[-2]}
	local total_bidirectional_client_bandwidth_units=${client_results[-1]}
	echo "Bi-directional network bandwidth is (client to server) :" \
		"$total_bidirectional_client_bandwidth" \
		"$total_bidirectional_client_bandwidth_units"
	echo "Bi-directional network bandwidth is (server to client) :" \
		"$total_bidirectional_server_bandwidth" \
		"$total_bidirectional_server_bandwidth_units"

	test_name="network bw client to server"
	save_results "$test_name" "client to server" \
		"$total_bidirectional_client_bandwidth" \
		"$total_bidirectional_client_bandwidth_units"
	test_name="network bw server to client"
	save_results "$test_name" "server to client" \
		"$total_bidirectional_server_bandwidth" \
		"$total_bidirectional_server_bandwidth_units"

	clean_env
	echo "Finish"
}

bidirectional_bandwidth_server_client
