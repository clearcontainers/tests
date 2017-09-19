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
# This metrics test measures the cpu % consumption while it is running a
# network/bandwidth workload using iperf tool in an interconnection
# container-client <------> container-server.

set -e

SCRIPT_PATH=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_PATH}/lib/network-common.bash"
source "${SCRIPT_PATH}/../lib/common.bash"
TEST_NAME="network cpu consumption"

# Set QEMU_PATH unless it's already set
QEMU_PATH=${QEMU_PATH:-$(get_qemu_path)}

# Measures cpu % consumption while running bandwidth measurements
# using iperf2.
function cpu_consumption() {
	# Port number where the server will run.
	# Server configuration, a container will work as a server, for this
	# it will run iperf in server mode, by default, the iperf client connects
	# to the iperf server on the TCP port 5001, for that reason the container
	# makes port forwarding to 5001.
	local port="5001:5001"
	# Using this image as iperf is not working
	# see (https://github.com/01org/cc-oci-runtime/issues/152)
	# Image name
	local image="gabyct/network"
	# Total measurement time (seconds)
	# This is required in order to reduce standard deviation
	local total_time=16
	# This time (seconds) is required when
	# server and client are more stable, we need to
	# have server and client running for sometime and we
	# need to avoid to measure at the beginning of the running
	local middle_time=8
	# Arguments to run the client
	local extra_args="-d"

	# Initialize/clean environment
	init_env

	local server_command="iperf -p ${port} -s"
	local server_address=$(start_server "$image" "$server_command")

	# Verify server IP address
	if [ -z "$server_address" ];then
		clean_env
		die "server: ip address no found"
	fi

	local client_command="iperf -c ${server_address} -t ${total_time}"
	start_client "$image" "$client_command" "$extra_args"

	# Measurement after client and server are more stable
	echo >&2 "WARNING: sleeping for $middle_time seconds in order to have server and client stable"
	sleep ${middle_time}

	# Check the runtime in order to determine which process will
	# be measured about cpu %
	if [ "$RUNTIME" == "runc" ]; then
		process="iperf"
	elif [ "$RUNTIME" == "cor" ] || [ "$RUNTIME" == "cc-runtime" ]; then
		process="$QEMU_PATH"
	else
		die "Unknown runtime: $RUNTIME"
	fi

	local total_cpu_consumption=$(ps --no-headers -o %cpu \
		-p $(pidof ${process}) | awk '{ total+= $1 } END { print total/NR }')
	echo "CPU % consumption: $total_cpu_consumption"

	save_results "$TEST_NAME" "" \
		"$total_cpu_consumption" "%"

	clean_env
	echo "Finish"
}

cpu_consumption
