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
# Description: This file contains functions that are shared among the networking
# tests that are using nuttcp and iperf

SCRIPT_PATH=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_PATH}/../lib/common.bash"

# This function will launch a container in detached mode and
# it will return the IP address, the role of this container is as a server.
# Arguments:
#  Docker image.
#  Command[s] to be executed.
#  Extra argument for container execution.
function start_server()
{
	local image="$1"
	local cmd="$2"
	local extra_args="$3"

	# Launch container
	instance_id="$($DOCKER_EXE run $extra_args -d --runtime "$RUNTIME" \
		"$image" sh -c "$cmd")"

	# Get IP Address
	server_address=$($DOCKER_EXE inspect \
		--format "{{.NetworkSettings.IPAddress}}" $instance_id)

	echo "$server_address"
}

# This function will launch a container and it will execute a determined
# workload, this workload is received as an argument and this function will
# return the output/result of the workload. The role of this container is as a client.
# Arguments:
#  Docker image
#  Command[s] to be executed
#  Extra argument for container execution
function start_client()
{
	local image="$1"
	local cmd="$2"
	local extra_args="$3"

	# Execute client/workload and return result output
	output="$($DOCKER_EXE run $extra_args --runtime "$RUNTIME" \
			"$image" sh -c "$cmd")"

	echo "$output"
}
