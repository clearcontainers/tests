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
# This metrics test measures the UDP network bandwidth using nuttcp
# in a interconnection container-client <----> container-server.

set -e

SCRIPT_PATH=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_PATH}/lib/network-common.bash"
source "${SCRIPT_PATH}/../lib/common.bash"


function udp_bandwidth() {
	# Currently default nuttcp has a bug
	# see https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=745051
	# Image name
	local image="gabyct/nuttcp"
	# Measurement time (seconds)
	local transmit_timeout=5
	# Name of the server container
	local server_name="network-server"

	# Arguments to run the client/server
	local server_extra_args="-i --name=$server_name"
	local client_extra_args="-ti --rm"

	# Initialize/clean environment
	init_env

	local server_command="sh"
	local server_address=$(start_server "$image" "$server_command" "$server_extra_args")

	local client_command="/root/nuttcp -T${transmit_timeout} -u -Ru -i1 -l${bl} ${server_address}"
	local server_command="/root/nuttcp -u -S"

	$DOCKER_EXE exec ${server_name} sh -c "${server_command}"
	result=$(start_client "$image" "$client_command" "$client_extra_args")


	local result_line=$(echo "$result" | tail -1)
	local -a results
	read -a results <<< ${result_line%$'\r'}

	# 6, 7, 16, "%"
	local total_bandwidth=${results[6]}
	local total_bandwidth_units=${results[7]}
	local total_loss=${results[16]}
	local total_loss_units="%"
	echo "UDP bandwidth is (${bl} buffer size) :" \
		"$total_bandwidth $total_bandwidth_units"
	echo "UDP % of packet loss is (${bl} buffer size) :" \
		"${total_loss}${total_loss_units}"

	local subtest_name="UDP ${bl}b buffer"
	test_name="network nuttcp UDP ${bl}b bandwith"
	save_results "${test_name}" "${subtest_name} bandwidth" \
		"$total_bandwidth" "$total_bandwidth_units"
	test_name="network nuttcp UDP ${bl}b packet loss"
	save_results "${test_name}" "${subtest_name} packet loss" \
		"$total_loss" "$total_loss_units"

	clean_env
	echo "Finish"

}

function udp_default_buffer_size {
	# Test UDP Jumbo (9000 byte MTU) packets
	# Packet header (ICMP+IP) is 28bytes, so maximum payload is 8972 bytes
	# See the nuttcp documentation for more hints:
	# https://fasterdata.es.net/performance-testing/network-troubleshooting-tools/nuttcp/
	bl=8972
	udp_bandwidth
}

function udp_specific_buffer_size {
	# Test UDP standard (1500 byte MTU) packets
	# Even though the packet header (ICMP+IP) is 28 bytes, which would
	# result in 1472 byte frames, the nuttcp documentation recommends
	# use of 1200 byte payloads, so let's run with that for now.
	# See the nuttcp examples.txt for more information:
	# http://nuttcp.net/nuttcp/5.1.3/examples.txt
	bl=1200
	udp_bandwidth
}

udp_default_buffer_size

udp_specific_buffer_size
