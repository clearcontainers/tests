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
#  Test inter (docker<->docker) bidirectional network bandwidth using iperf2

SCRIPT_PATH=$(dirname "$(readlink -f "$0")")

source "${SCRIPT_PATH}/lib/network-test-common.bash"

set -e

# This script will perform all the measurements using a local setup

# Test TCP bandwidth bi-directionally (docker_iperf_server<->docker_iperf_client)
# Extract bandwidth results for both directions from the one test
function bidirectional_bandwidth_server_client {
	# Port number where the server will run
	local port=5001:5001
	# Image name
	local image=gabyct/network
	# Measurement time (seconds)
	local time=5
	# Name of the containers
	local server_name="network-server"
	local client_name="network-client"
	# Arguments to run the client
	local extra_args="-ti --rm"

	setup
	server_command="iperf -p ${port} -s"
	local server_address=$(start_server "$server_name" "$image" "$server_command")

	client_command="iperf -c ${server_address} -d -t ${time}"
	start_client "$extra_args" "$client_name" "$image" "$client_command" > "$result"

	local server_result=$(tail -1 $result)
	read -a server_results <<< ${server_result%$'\r'}
	local client_result=$(tail -n 2 $result | head -1)
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

	save_results "network metrics" "client to server" \
		"$total_bidirectional_client_bandwidth" \
		"$total_bidirectional_client_bandwidth_units"
	save_results "network metrics" "server to client" \
		"$total_bidirectional_server_bandwidth" \
		"$total_bidirectional_server_bandwidth_units"

	clean_environment "$server_name"
}

bidirectional_bandwidth_server_client
