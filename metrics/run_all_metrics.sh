#!/bin/bash
#
# Copyright (c) 2017 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

SCRIPT_PATH=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_PATH}/lib/common.bash"

# Set up the initial state
onetime_init

# Check arguments
if [[ ! -v RUNTIME ]]; then
    die Variable RUNTIME must be set to the name of your CC runtime
fi

SCRIPT_PATH=$(dirname "$(readlink -f "$0")")

# Check tools/commands dependencies
echo "Check dependencies"
cmds=("docker" "bc" "awk" "smem" "ab")
check_cmds "${cmds[@]}"

function help() {
echo "$(cat << EOF
Usage: $0 [-h] [--help] [-v] [--version]
   Description:
        This script allows to execute the metrics tests
        in different groups which are focused in different
        aspects of the containers. If no option is specified
        all tests will be executed.
   Options:
        -h, --help         Shows help
        -l, --latency      Run latency/time metrics tests
        -m, --memory       Run memory metrics tests
        -n, --network      Run network metrics tests
        -s, --storage      Run I/O storage metrics tests
EOF
)"
}

# Only run latency metrics tests
function run_latency_tests() {
	# Run the time tests
	bash ${SCRIPT_PATH}/time/docker_workload_time.sh true busybox $RUNTIME 100
	# Launch time for first container - no scaling, with network
	bash ${SCRIPT_PATH}/time/launch_times.sh -i ubuntu -n 100
	# With scaling
	bash ${SCRIPT_PATH}/time/launch_times.sh -i ubuntu -n 100 -s
	# With no network, no scaling
	bash ${SCRIPT_PATH}/time/launch_times.sh -i ubuntu -n 100 -d
	# With scaling, no network
	bash ${SCRIPT_PATH}/time/launch_times.sh -i ubuntu -n 100 -s -d
}

# Only run network metrics tests
function run_network_tests() {
	# Run the network metrics
	bash ${SCRIPT_PATH}/network/network-latency.sh
	bash ${SCRIPT_PATH}/network/network-latency-qperf.sh
	bash ${SCRIPT_PATH}/network/network-metrics-cpu-consumption.sh
	bash ${SCRIPT_PATH}/network/network-metrics-iperf3.sh
	bash ${SCRIPT_PATH}/network/network-metrics-memory-pss-1g.sh
	bash ${SCRIPT_PATH}/network/network-metrics-memory-pss.sh
	bash ${SCRIPT_PATH}/network/network-metrics-memory-rss-1g.sh
	bash ${SCRIPT_PATH}/network/network-metrics-nuttcp.sh
	bash ${SCRIPT_PATH}/network/network-metrics.sh
	bash ${SCRIPT_PATH}/network/network-nginx-ab-benchmark.sh
}

# Only run memory/density metrics tests
function run_memory_tests() {
	# Run the density/footprint scripts
	# If you have KSM enabled, the 'settle time' depends on the default settings.
	# For instance, for an Ubuntu 16.04 default install, it takes about 200s for
	# 20 CC containers footprint to 'settle down'.
	#
	# Presume KSM is off, and hence no need to have a settle time
	bash ${SCRIPT_PATH}/density/docker_memory_usage.sh 20 1
}

# Only run I/O storage metrics tests
function run_storage_tests() {
	# Run I/O storage tests

	# Block Size and Ramp Time Settings for Fio Test
        BLOCK_SIZE="16k"
        RAMP_TIME="60"

	bash ${SCRIPT_PATH}/storage/fio_job.sh -b ${BLOCK_SIZE} -u ${RAMP_TIME} -o randread -t "storage IO random read bs ${BLOCK_SIZE}"
	bash ${SCRIPT_PATH}/storage/fio_job.sh -b ${BLOCK_SIZE} -u ${RAMP_TIME} -o randwrite -t "storage IO random write bs ${BLOCK_SIZE}"
	bash ${SCRIPT_PATH}/storage/fio_job.sh -b ${BLOCK_SIZE} -u ${RAMP_TIME} -o read -t "storage IO linear read bs ${BLOCK_SIZE}"
	bash ${SCRIPT_PATH}/storage/fio_job.sh -b ${BLOCK_SIZE} -u ${RAMP_TIME} -o write -t "storage IO linear write bs ${BLOCK_SIZE}"
}

# Run all metrics tests
function run_all_tests() {
	run_latency_tests
	run_network_tests
	run_memory_tests
	run_storage_tests
}

# This script will run all metricts tests by default if no
# option is specified.
function main() {
	if [ $# -eq 0 ]; then
		echo "Running all metrics tests"
		run_all_tests
		exit 0
	fi

	while (( $# )); do
		case $1 in
		-h|--help)
			help
			exit 0;
		;;
		-l|--latency)
			run_latency_tests
		;;
		-m|--memory)
			run_memory_tests
		;;
		-n|--network)
			run_network_tests
		;;
		-s|--storage)
			run_storage_tests
		;;
		esac
		shift
	done

	exit 0
}

main "$@"
