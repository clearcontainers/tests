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
# This metrics test measures the TCP latency using qperf acting between two
# containers.

set -e

SCRIPT_PATH=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_PATH}/lib/network-common.bash"
source "${SCRIPT_PATH}/../lib/common.bash"
TEST_NAME="network qperf TCP latency"

function latency() {
	# Image name (qperf installed by default)
	local image="gabyct/network"
	# Arguments to run the client/server
	local client_extra_args="--rm"
	local server_extra_args=""

	# Initialize/clean environment
	init_env
	check_images "$image"

	local server_command="qperf"
	local server_address=$(start_server "$image" "$server_command" "$server_extra_args")

	# Verify server IP address
	if [ -z "$server_address" ];then
		clean_env
		die "server: ip address no found"
	fi

	local client_command="qperf ${server_address} tcp_lat conf"
	result=$(start_client "$image" "$client_command" "$client_extra_args")

	local total_latency=$(echo "$result" | grep latency | cut -f2 -d '=' | awk '{print $1}')
	local units=$(echo "$result" | grep latency | cut -f2 -d '=' | awk '{print $2}' | tr -d '\r')

	echo "Ping total latency: $total_latency $units"

	# Note, for now we save with the units we get from the results - but at some
	# point we might wish to unify the results into a stated fixed unit (ns or so)
	# so we have uniformity in the historical data records.
	save_results "$TEST_NAME" "" "${total_latency}" "${units}"

	clean_env
	echo "Finish"
}

latency
