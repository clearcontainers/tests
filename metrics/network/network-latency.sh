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
# This metrics test measures the latency spent when a container makes a ping
# to another container.
# container-client <--- ping ---> container-server

set -e

SCRIPT_PATH=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_PATH}/lib/network-common.bash"
source "${SCRIPT_PATH}/../lib/common.bash"
TEST_NAME="network ping latency"

function latency() {
	# Image name (ping installed by default)
	local image="busybox"
	# Number of packets (sent)
	local number=10
	# Arguments to run the client/server
	local client_extra_args="--rm"
	local server_extra_args=""

	# Initialize/clean environment
	init_env
	check_images "$image"

	local server_command="tail -f /dev/null"
	local server_address=$(start_server "$image" "$server_command" "$server_extra_args")

	# Verify server IP address
	if [ -z "$server_address" ];then
		clean_env
		die "server: ip address no found"
	fi

	local client_command="ping -c ${number} ${server_address}"
	result=$(start_client "$image" "$client_command" "$client_extra_args")

	local latency_average="$(echo "$result" | grep "avg" | awk -F"/" '{print $4}')"
	echo "Ping latency average: $latency_average ms"

	save_results "$TEST_NAME" "" "${latency_average}" "ms"

	clean_env
	echo "Finish"
}

latency
