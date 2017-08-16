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

#  Description of the test:
#  This test launches a number of containers in idle mode,
#  It will then sleep for a configurable period of time to allow
#  any memory optimisations to 'settle, and then checks the
#  amount of memory used by all the containers to come up with
#  an average (using the PSS measurements)
#  This test uses smem tool to get the memory used.

set -e

SCRIPT_PATH=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_PATH}/../lib/common.bash"

# Busybox image: Choose a small workload image, this is
# in order to measure the runtime footprint, not the workload
# footprint.
IMAGE='busybox'

CMD='sh'
NUM_CONTAINERS="$1"
WAIT_TIME="$2"
TEST_NAME="memory footprint"
TEST_ARGS="workload=${IMAGE} units=kb"
# Set QEMU_PATH unless it's already set
QEMU_PATH=${QEMU_PATH:-$(get_qemu_path)}
SMEM_BIN="smem"
KSM_ENABLE_FILE="/sys/kernel/mm/ksm/run"

# Show help about this script
function help(){
cat << EOF
Usage: $0 <count> <wait_time>
   Description:
        <count>      : Number of Clear Containers to run.
        <wait_time>  : Time in seconds to wait before taking
                       metrics.
EOF
}

# See if KSM is enabled.
# If so, ammend the test name to reflect that
function check_for_ksm(){
	if [ ! -f ${KSM_ENABLE_FILE} ]; then
		return
	fi

	ksm_on=$(< ${KSM_ENABLE_FILE})

	if [ $ksm_on == "1" ]; then
		TEST_NAME="${TEST_NAME} ksm"
	fi
}

# This function measures the PSS average
# memory of a process.
function get_pss_memory(){
	ps="$1"
	mem_amount=0
	count=0
	avg=0

	data=$("$SMEM_BIN" --no-header -P "^$ps" -c "pss")
	for i in $data;do
		if (( i > 0 ));then
			mem_amount=$(( i + mem_amount ))
			(( count++ ))
		fi
	done

	if (( $count > 0 ));then
		avg=$(bc -l <<< "scale=2; $mem_amount / $count")
	fi

	echo "$avg"
}

# It calculates the memory footprint
# of a CC.
function get_docker_memory_usage(){
	qemu_mem=0
	cc_shim_mem=0
	proxy_mem=0
	cc_proxy_mem=0

	containers=()

	for ((i=1; i<= NUM_CONTAINERS; i++)); do
		containers+=($(random_name))
		${DOCKER_EXE} run --runtime "$RUNTIME" --name ${containers[-1]} -tid $IMAGE $CMD
	done

	# If KSM is enabled, then you normally want to sleep long enough to
	# let it do its work and for the numbers to 'settle'.
	sleep "$WAIT_TIME"

	# Get PSS memory of CC components.
	# And check that the smem search has found the process - we get a "0"
	#  back if that procedure fails (such as if a process has changed its name
	#  or is not running when expected to be so)
	# As an added bonus - this script must be run as root (or at least as
	#  a user with enough rights to allow smem to read the smap stats for
	#  the docker owned processes). Now if you do not have enough rights
	#  the smem failure to read the stats will also be trapped.
	qemu_mem="$(get_pss_memory "$QEMU_PATH")"
	if [ "$qemu_mem" == "0" ]; then
		die "Failed to find PSS for $QEMU_PATH"
	fi

	cc_shim_mem="$(get_pss_memory "$CC_SHIM_PATH")"
	if [ "$cc_shim_mem" == "0" ]; then
		die "Failed to find PSS for $CC_SHIM_PATH"
	fi

	proxy_mem="$(get_pss_memory "$CC_PROXY_PATH")"
	if [ "$proxy_mem" == "0" ]; then
		die "Failed to find PSS for $CC_PROXY_PATH"
	fi

	cc_proxy_mem="$(bc -l <<< "scale=2; $proxy_mem / $NUM_CONTAINERS")"
	cc_mem_usage="$(bc -l <<< "scale=2; $qemu_mem + $cc_shim_mem + $cc_proxy_mem")"

	save_results "$TEST_NAME" "$TEST_ARGS" "$cc_mem_usage" "KB"
	docker rm -f ${containers[@]}
}

# Verify enough arguments
if [[ $# != 2 ]];then
	echo >&2 "error: Not enough arguments [$@]"
	help
	exit 1
fi

#Check for KSM before reporting test name, as it can modify it
check_for_ksm

echo "Executing Test: ${TEST_NAME}"

check_cmds "${SMEM_BIN}" bc
init_env

get_docker_memory_usage
