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

#  Description of the test:
#  This test takes a number of time measurements through the complete
#  launch/shutdown cycle of a single container.
#  From those measurements it derives a number of time measures, such as:
#   - time to payload execution
#   - time to get to VM kernel
#   - time in VM kernel boot
#   - time to quit
#   - total time (from launch to finished)
#
# Note, the <image> used for this test must support the full 'date' command
# syntax - the date from busybox for isntance *does not* support this, so
# will not work with this test.
#
# Note, this test launches a single container at a time, that quits - thus,
# this test measures times for the 'first container' only. This test does
# not look for any scalability slowdowns as the number of running containers
# increases for instance - that is handled in other tests

set -e

SCRIPT_PATH=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_PATH}/../lib/common.bash"

# Calculating the kernel time from dmesg stamps only really works for VM
# based runtimes - we dynamically enable it if we find we are using a known
# VM runtime
CALCULATE_KERNEL=

REQUIRED_CMDS=("bc" "awk")

# The date command format we use to ensure we capture the ns timings
# Note the no-0-padding - 0 padding the results breaks bc in some cases
DATECMD="date -u +%-s:%-N"


# convert a 'seconds:nanoseconds' string into nanoseconds
sn_to_ns() {
	# use shell magic to strip out the 's' and 'ns' fields and print
	# them as a 0-padded ns string...
	printf "%d%09d" ${1%:*} ${1##*:}
}

# convert 'nanoseconds' (since epoch) into a 'float' seconds
ns_to_s() {
	echo $(bc <<< "scale=3; $1 / 1000000000")
}

# Ensure we have yanked down the necessary images before we begin - we do not
# want to be adding that overhead into any of our measurement times
prewarm() {
	echo "Pre-warming by pulling $IMAGE"
	docker pull $IMAGE
}

run_workload() {
	start_time=$($DATECMD)

	# Run the image and command and capture the results into an array...
	declare workload_result
	readarray -n 0 workload_result < <(docker run --rm -ti --runtime=${RUNTIME} ${NETWORK_OPTION} ${IMAGE} sh -c "$DATECMD; dmesg")

	end_time=$($DATECMD)

	# Delay this calculation until after we have run - do not want
	# to measure it in the results
	start_time=$(sn_to_ns $start_time)
	end_time=$(sn_to_ns $end_time)

	# Extracte the 'date' info from the first line of the log
	# This script assumes the VM clock is in sync with the host clock...
	workload_time=${workload_result[0]}
	workload_time=$(echo $workload_time | tr -d '\r')
	workload_time=$(sn_to_ns $workload_time)

	# How long did the whole launch/quit take
	total_period=$((end_time-start_time))
	# How long did it take to get to the workload
	workload_period=$((workload_time-start_time))
	# How long did it take to quit
	shutdown_period=$((end_time-workload_time))

	if [ -n "$CALCULATE_KERNEL" ]; then
		# Grab the last kernel dmesg time
		# In our case, we need to find the last real kernel line before
		# the systemd lines begin. The last:
		# 'Freeing unused kernel memory' line is a reasonable
		# 'last in kernel line' to look for.
		# We make a presumption here that as we are in a cold-boot VM
		# kernel, the first dmesg is at '0 seconds', so the timestamp
		# of that last line is the length of time in the kernel.
		kernel_last_line=$( (fgrep "Freeing unused kernel memory" <<- EOF
				${workload_result[@]}
			EOF
			) | tail -1 )
		kernel_period=$(echo $kernel_last_line | awk '{print $2}' | tr -d "]")

		# And we can then work out how much time it took to get to the kernel
		to_kernel_period=$(bc <<<"scale=3; $(ns_to_s $workload_period) - $kernel_period")
	fi

	# And store the results...
	save_results "${TEST_NAME}-total" "$TEST_ARGS" "$(ns_to_s $total_period)" "s"
	save_results "${TEST_NAME}-workload" "$TEST_ARGS" "$(ns_to_s $workload_period)" "s"
	if [ -n "$CALCULATE_KERNEL" ]; then
		save_results "${TEST_NAME}-kernel" "$TEST_ARGS" "$kernel_period" "s"
		save_results "${TEST_NAME}-to-kernel" "$TEST_ARGS" "$to_kernel_period" "s"
	fi
	save_results "${TEST_NAME}-quit" "$TEST_ARGS" "$(ns_to_s $shutdown_period)" "s"

	# If we are doing an (optional) scaling test, then we launch a permanent container
	# between each of our 'test' containers. The aim being to see if our launch times
	# are linear with the number of running containers or not
	if [ -n "$SCALING" ]; then
		docker run -d ${IMAGE} sh -c "tail -f /dev/null"
	fi
}

init () {
	TEST_ARGS="image=${IMAGE} runtime=${RUNTIME} units=seconds"

	# We set the generic name here, but we save the different time results separately,
	# and append the actual detail to the name at the time of saving...
	TEST_NAME="boot times"

	# If we are scaling, note that in the name
	[ -n "$SCALING" ] && TEST_NAME="${TEST_NAME} scaling"

	[ -n "$NONETWORKING" ] && NETWORK_OPTION="--network none" && \
		TEST_NAME="${TEST_NAME} nonet"

	echo "Executing test: ${TEST_NAME} ${TEST_ARGS}"
	check_cmds "${REQUIRED_CMDS[@]}"

	if [ "$RUNTIME" == "cor" ] || [ "$RUNTIME" == "cc-runtime" ]; then
		CALCULATE_KERNEL=1
	fi

	# Start from a fairly clean environment
	init_env
	prewarm
}

help() {
	usage=$(cat << EOF
Usage: $0 [-h] [options]
   Description:
        This script takes time measurements for different
	stages of a boot/run/rm cycle
   Options:
        -d,         Disable network bringup
        -h,         Help
        -i <name>,  Image name (mandatory)
        -n <n>,     Number of containers to run (mandatory)
        -r <name>,  Docker runtime to use
        -s,         Enable scaling (keep containers running)
EOF
)
	echo "$usage"
}

main() {
	local OPTIND
	while getopts "dhi:n:sr:" opt;do
		case ${opt} in
		d)
		    NONETWORKING=true
		    ;;
		h)
		    help
		    exit 0;
		    ;;
		i)
		    IMAGE="${OPTARG}"
		    ;;
		n)
		    TIMES="${OPTARG}"
		    ;;
		r)
		    RUNTIME="${OPTARG}"
		    ;;
		s)
		    SCALING=true
		    ;;
		?)
		    # parse failure
		    help
		    die "Failed to parse arguments"
		    ;;
		esac
	done
	shift $((OPTIND-1))

	[ -z "$IMAGE" ] && help && die "Mandatory IMAGE name not supplied"
	[ -z "$TIMES" ] && help && die "Mandatory nunmber of containers not supplied"
	# Although this is mandatory, the 'lib/common.bash' environment can set
	# it, so we may not fail if it is not set on the command line...
	[ -z "$RUNTIME" ] && help && die "Mandatory runtime argument not supplied"

	init
	for i in $(seq 1 "$TIMES"); do
		run_workload
	done
	clean_env
}

main "$@"
