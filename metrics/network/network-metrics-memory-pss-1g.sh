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
# This metrics test measures Proportional Set Size memory while an interconnection
# between container-client <----> container-server transfers 1 Gb rate as a
# network workload using nuttcp.
#
# The selection of 1 Gb as a tranfer rate is because that is
# the maximum that we can be handle in our testing infrastructure.

set -e

SCRIPT_PATH=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_PATH}/lib/network-common.bash"
source "${SCRIPT_PATH}/../lib/common.bash"
TEST_NAME="network memory pss 1g"

# Set QEMU_PATH unless it's already set
QEMU_PATH=${QEMU_PATH:-$(get_qemu_path)}

function pss_memory() {
	# Currently default nuttcp has a bug
	# see https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=745051
	# Image name
	local image="gabyct/nuttcp"
	# We wait for the test system to settle into a steady mode before we
	# measure the PSS. Thus, we have two times - the length of the time the
	# test runs for, and the time after which we sample the PSS
	# Time for the test to run (seconds)
	local total_time=6
	# Time in which we sample the PSS (seconds)
	local middle_time=3
	# Rate limit (speed at which transmitter send data, megabytes)
	# We will measure PSS with a specific transfer rate
	local rate_limit=1000
	local server_name="network-server"
	# Arguments to run the client/server
	local client_extra_args="-d"
	local server_extra_args="-i --name=$server_name"

	# Initialize/clean environment
	init_env

	local server_command="sh"
	local server_address=$(start_server "$image" "$server_command" "$server_extra_args")

	# Verify server IP address
	if [ -z "$server_address" ];then
		clean_env
		die "server: ip address no found"
	fi

	local client_command="/root/nuttcp -R${rate_limit}m -T${total_time} ${server_address}"
	local server_command="/root/nuttcp -S"

	# Execute nuttcp workload in container server
	$DOCKER_EXE exec ${server_name} sh -c "${server_command}"
	start_client "$image" "$client_command" "$client_extra_args"

	# Time when we are taking our PSS measurement
	echo >&2 "WARNING: sleeping for $middle_time seconds in order to sample the PSS"
	sleep ${middle_time}

	# Check the runtime in order to determine which process will
        # be measured about PSS memory consumption.
        if [ "$RUNTIME" == "runc" ]; then
                process="/root/nuttcp"
        elif [ "$RUNTIME" == "cor" ] || [ "$RUNTIME" == "cc-runtime" ]; then
                process="$QEMU_PATH"
        else
                die "Unknown runtime: $RUNTIME"
        fi

	local memory_command="sudo smem --no-header -c pss"
	result=$(${memory_command} -P ^${process})

	local memory=$(echo "$result" | awk '{ total += $1 } END { print total/NR }')
	echo "PSS memory: $memory Kb"

	save_results "$TEST_NAME" "pss 1g" "$memory" "kb"

	echo >&2 "WARNING: This test is being affected by https://github.com/01org/cc-oci-runtime/issues/795"

	clean_env
	echo "Finish"
}

pss_memory
