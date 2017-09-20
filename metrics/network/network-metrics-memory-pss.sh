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
# This metrics test measures Proportional Set Size memory while it is running
# a network bandwidth workload using iperf2 tool in an interconnection
# container-client <----> container-server.

set -e

SCRIPT_PATH=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_PATH}/lib/network-common.bash"
source "${SCRIPT_PATH}/../lib/common.bash"
TEST_NAME="network metrics memory pss"

# Set QEMU_PATH unless it's already set
QEMU_PATH=${QEMU_PATH:-$(get_qemu_path)}

function pss_memory() {
	# Port number where the server will run
	local port="5001:5001"
	# Using this image as iperf is not working
	# see (https://github.com/01org/cc-oci-runtime/issues/152)
	# Image name
	local image="gabyct/network"
	# Total measurement time (seconds)
	# This is required in order to reduce standard deviation
	local total_time=10
	# This time (seconds) is required when
	# server and client are more stable, we need to
	# have server and client running for sometime and we
	# need to avoid to measure at the beginning of the running
	local middle_time=5
	# Arguments to run the client
	local extra_args="-d"

	# Initialize/clean environment
	init_env

	local server_command="iperf -p ${port} -s"
	local server_address=$(start_server "$image" "$server_command")

	local client_command="iperf -c ${server_address} -t ${total_time}"
	start_client "$image" "$client_command" "$extra_args"

	# Measurement after client and server are more stable
	echo >&2 "WARNING: sleeping for $middle_time seconds in order to have server and client stable"
	sleep ${middle_time}

	# Check the runtime in order to determine which process will
        # be measured about PSS memory consumption.
        if [ "$RUNTIME" == "runc" ]; then
                process="iperf"
        elif [ "$RUNTIME" == "cor" ] || [ "$RUNTIME" == "cc-runtime" ]; then
                process="$QEMU_PATH"
        else
                die "Unknown runtime: $RUNTIME"
        fi

	local memory_command="smem --no-header -c pss"
	result=$(${memory_command} -P ^${process})

	local total_pss_memory=$(echo "$result" | awk '{ total += $1 } END { print total/NR }')
	echo "PSS memory: $total_pss_memory Kb"

	save_results "$TEST_NAME" "pss" "$total_pss_memory" "kb"

	clean_env
	echo "Finish"
}

pss_memory
