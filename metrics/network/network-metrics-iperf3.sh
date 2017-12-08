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
# This test measures the following network essentials:
# - bandwith simplex
# - bandwith duplex
# - jitter
#
# These metrics/results will be got from the interconnection between
# a client and a server using iperf tool.
# The following cases are covered:
#
# case 1:
#  container-server <----> container-client
#
# case 2"
#  container-server <----> host-client

set -e

SCRIPT_PATH=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_PATH}/lib/network-common.bash"
source "${SCRIPT_PATH}/../lib/common.bash"

TEST_NAME="iperf3 tests"

# Port number where the server will run
port="5201"
fwd_port="${port}:${port}"
# Image name
image="gabyct/network"
# Measurement time (seconds)
transmit_timeout=5
# Arguments to run the client/server
# "privileged" argument enables access to all devices on
# the host and it allows to avoid conflicts with AppArmor
# or SELinux configurations.
if [ "$RUNTIME" == "runc" ]; then
	extra_capability="--privileged"
fi

# Client/Server extra configuration
client_extra_args="$extra_capability --rm"
server_extra_args="$extra_capability"

# Iperf server configuration
# Set the TMPDIR to an existing tmpfs mount to avoid a 9p unlink error
# Note, this requires an upto date iperf3 >= v3.2 or thereabouts, which
# the gabyct/network image now has.
init_cmds="export TMPDIR=/dev/shm"
server_command="$init_cmds && iperf3 -s"


# Test single direction TCP bandwith
function iperf3_bandwidth() {
	local test_name="network iperf bandwidth"
	local server_address=$(start_server "$image" "$server_command" "$server_extra_args")

	# Verify server IP address
	if [ -z "$server_address" ];then
		clean_env
		die "server: ip address no found"
	fi

	local client_command="$init_cmds && iperf3 -c ${server_address} -t ${transmit_timeout}"
	result=$(start_client "$image" "$client_command" "$client_extra_args")

	local result_line=$(echo "$result" | grep -m1 -E '\breceiver\b')
	local -a results
	read -a results <<< $result_line
	local total_bandwidth=${results[6]}
	local total_bandwidth_units=${results[7]}
	echo "Network bandwidth is : $total_bandwidth $total_bandwidth_units"

	save_results "${test_name}" "network bandwidth" \
		"$total_bandwidth" "$total_bandwidth_units"
	clean_env
	echo "Finish"
}

# Test jitter on single direction UDP
function iperf3_jitter() {
	local test_name="network iperf jitter"
	local server_address=$(start_server "$image" "$server_command" "$server_extra_args")

	# Verify server IP address
	if [ -z "$server_address" ];then
		clean_env
		die "server: ip address no found"
	fi

	local client_command="$init_cmds && iperf3 -c ${server_address} -u -t ${transmit_timeout}"
	result=$(start_client "$image" "$client_command" "$client_extra_args")

	local result_line=$(echo "$result" | grep -m1 -A1 -E '\bJitter\b' | tail -1)
	local -a results
	read -a results <<< $result_line
	local total_jitter=${results[8]}
	local total_jitter_units=${results[9]}
	echo "Network jitter is : $total_jitter $total_jitter_units"

	save_results "${test_name}" "network jitter" \
		"$total_jitter" "$total_jitter_units"
	clean_env
	echo "Finish"
}

# Run bi-directional TCP test, and extract results for both directions
function iperf3_bidirectional_bandwidth_client_server() {
	local test_name="network iperf client to server"
	local server_address=$(start_server "$image" "$server_command" "$server_extra_args")

	# Verify server IP address
	if [ -z "$server_address" ];then
		clean_env
		die "server: ip address no found"
	fi

	local client_command="$init_cmds && iperf3 -c ${server_address} -d -t ${transmit_timeout}"
	result=$(start_client "$image" "$client_command" "$client_extra_args")

	local client_result=$(echo "$result" | grep -m1 -E '\breceiver\b')
	local server_result=$(echo "$result" | grep -m1 -E '\bsender\b')
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

	# Save results in different files
	test_name="network iperf server to client"

	save_results "${test_name}" "network bidir bw server to client" \
		"$total_bidirectional_server_bandwidth" \
		"$total_bidirectional_server_bandwidth_units"
	clean_env
	echo "Finish"
}

# This function checks/verify if the iperf server
# is ready/up for requests.
function check_iperf_server() {
	# timeout of 3 seconds aprox.
	local time_out=6
	local period=0.5
	local test_cmd="iperf3 -c "$server_address" -t 1"

	# check tools dependencies
	local cmds=("netstat")
	check_cmds "${cmds[@]}"

	while [ 1 ]; do
		if ! bash -c "$test_cmd" > /dev/null 2>&1; then
			echo "waiting for server..."
			count=$((count+1))
			sleep $period
		else
			echo "iperf server is up!"
			break;
		fi

		if [ "$count" == "$time_out" ]; then
			die "iperf server init fails"
		fi
	done

	# Check listening port
	lport="$(netstat -atun | grep "$port" | grep "LISTEN")"
	if [ -z "$lport" ]; then
		die "port is not listening"
	fi

}

# This function parses the output of iperf execution, and
# saves the bandwidth results in CSV files
function parse_iperf_bwd() {
	local test_name="$1"
	local result="$2"

	if [ -z "$result" ]; then
		die "no result output"
	fi

	# Filter receiver/sender results
	rx_res=$(echo "$result" | grep "receiver" | awk -F "]" '{print $2}')
	tx_res=$(echo "$result" | grep "sender" | awk -F "]" '{print $2}')

	# Getting results
	rx_bwd=$(echo "$rx_res" | awk '{print $5}')
	tx_bwd=$(echo "$tx_res" | awk '{print $5}')
	rx_uts=$(echo "$rx_res" | awk '{print $6}')
	tx_uts=$(echo "$tx_res" | awk '{print $6}')

	# Save results in CSV files
	save_results "${test_name} receiver" "" "$rx_bwd" "$rx_uts"
	save_results "${test_name} sender" "" "$tx_bwd" "$tx_uts"

	# Show results
	echo "$test_name"
	echo "Receiver bandwidth $mode : $rx_bwd $rx_uts"
	echo "Sender bandwidth $mode : $tx_bwd $tx_uts"

}

# This function launches a container that will take the role of
# server, this is order to attend requests from a client.
# In this case the client is an instance of iperf running in the host.
function get_host_cnt_bwd() {
	local cli_args="$1"

	# Checks iperf3 tool installed in host
	local cmds=("iperf3")
	check_cmds "${cmds[@]}"

	# Initialize/clean environment
	init_env

	# Make port forwarding
	local server_extra_args="$server_extra_args -p $fwd_port"
	local server_address=$(start_server "$image" "$server_command" "$server_extra_args")

	# Verify server IP address
        if [ -z "$server_address" ];then
                clean_env
                die "server: ip address no found"
        fi

	# Verify the iperf server is up
	check_iperf_server

	# client test executed in host
	local output=$(iperf3 -c $server_address -t $transmit_timeout "$cli_args")

	clean_env
	echo "Finish"

	echo "$output"
}

# This test measures the bandwidth between a container and the host.
# where the container take the server role and the iperf client lives
# in the host.
function iperf_host_cnt_bwd() {
	local test_name="newtwork bwd host contr"
	local result="$(get_host_cnt_bwd)"
	parse_iperf_bwd "$test_name" "$result"
}

# This test is similar to "iperf_host_cnt_bwd", the difference is this
# tests runs in reverse mode.
function iperf_host_cnt_bwd_rev() {
	local test_name="network bwd host contr reverse"
	local result="$(get_host_cnt_bwd "-R")"
	parse_iperf_bwd "$test_name" "$result"
}

# This tests measures the bandwidth using different number of parallel
# client streams. (2, 4, 8)
function iperf_multiqueue() {
	local test_name="network multiqueue"
	local client_streams=("2" "4" "8")

	for s in "${client_streams[@]}"; do
		tn="$test_name $s"
		result="$(get_host_cnt_bwd "-P $s")"
		sum="$(echo "$result" | grep "SUM" | tail -n2)"
		parse_iperf_bwd "$tn" "$sum"
	done
}

init_env

check_images "$image"

iperf3_bandwidth

iperf3_jitter

iperf_host_cnt_bwd

iperf_host_cnt_bwd_rev

iperf_multiqueue

iperf3_bidirectional_bandwidth_client_server
