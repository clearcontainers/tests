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
#  This test measures the bandwidth measured by a specif I/O
#  operation (read, write, random-read etc) under certain configuration.
#  The result is obtained using FIO tool, it runs inside of a container.

set -e

# General env
SCRIPT_PATH=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_PATH}/../lib/common.bash"
TEST_ARGS="$@"

# These values are a basic configuration for a FIO job
# execution, however they could be overridden in order to
# run a customized FIO job.
BLOCK_SIZE="4k"
ENGINE="sync"
FILE_SIZE="4G"
FIO_TEST_NAME="io_test"
NUM_JOBS="1"
OPERATION="randread"
TEST_NAME="storage fio test"
EXTRA_ARGS=""
TEST_TIME="300"
RAMP_TIME="60"
DIRECT_VALUE="1"
INVALIDATE_VALUE="1"
STATUS_TIME="30"

# This docker image includes FIO tool.
FIO_IMAGE="clusterhq/fio-tool"

# We need to know which QEMU to monitor
QEMU_PATH=${QEMU_PATH:-$(get_qemu_path)}

# The FIO tool included in clusterhq/fio-tool docker image
# works in "/tmp" by default. "/tmp" is overridden by /home
# mount point in order to avoid tmpfs and use the disk.
FILE_NAME="/home/fio_test"

declare FIO_RUN_JOB
declare FIO_PREP_JOB

function help()
{
	usage=$(cat << EOF
Usage: $0 [-h] [options]
   Description:
        This script show I/O bandwidth in KB/s
        of containers using FIO tool.
   Options:
        -h,    Help page.
        -b,    Block size for I/O units.
        -e,    FIO engine.
        -f,    Total  size  of  I/O for this job.
        -o,    I/O operation e.g. read, write etc.
        -n,    Max number of jobs.
        -r,    Runtime for docker.
        -t,    Test name.
        -u,    Ramp time.
        -x,    Extra fio arguments.
EOF
)
	echo "$usage"
}

# Create the job configuration for FIO
# this job will run inside of the container.
# This job sets up the image - creates the test file
function create_fio_prep_job()
{
	FIO_PREP_JOB="$(cat << EOF
	# This fio job will run inside of
	# the container.
	# It only runs for 1s, its job is to create
	# the test file

	fio --ioengine="$ENGINE" \
		--name="$FIO_TEST_NAME" \
		--filename="$FILE_NAME" \
		--bs="$BLOCK_SIZE" \
		--size="$FILE_SIZE" \
		--time_based \
		--direct="$DIRECT_VALUE" \
		--invalidate="$INVALIDATE_VALUE" \
		--status-interval="$STATUS_TIME" \
		--ramp_time="$RAMP_TIME" \
		--readwrite="$OPERATION" --max-jobs=$NUM_JOBS \
		--runtime=1 \
		${EXTRA_ARGS}
EOF
)"
}

# Create the job configuration for FIO
# this job will run inside of the container.
# This job runs the actual test
function create_fio_run_job()
{
	FIO_RUN_JOB="$(cat << EOF
	# This fio job will run inside of
	# the container.

	fio --ioengine="$ENGINE" \
		--name="$FIO_TEST_NAME" \
		--filename="$FILE_NAME" \
		--bs="$BLOCK_SIZE" \
		--size="$FILE_SIZE" \
		--time_based \
		--direct="$DIRECT_VALUE" \
		--invalidate="$INVALIDATE_VALUE" \
		--status-interval="$STATUS_TIME" \
		--ramp_time="$RAMP_TIME" \
		--readwrite="$OPERATION" --max-jobs=$NUM_JOBS \
		--runtime="$TEST_TIME" \
		${EXTRA_ARGS}
EOF
)"
}
# Parse the output of FIO tool in order to get
# the bandwidth average cosunmed by the FIO job.
# Also this function will convert results in KB/s
# if it is necessary.
function parse_fio_results()
{
	raw_data="$1"
	bw_data=$(echo "$raw_data" |  grep "bw (")

	if [ -z "$bw_data" ];then
		die "bandwidth result not found: check FIO job configuration"
	fi

	units=$(echo "$bw_data" | sed 's/^.*bw (/bw (/' | cut -f1 -d ':' | cut -f2 -d '(' | cut -f1 -d ')' | tail -1)
	avg=$(echo "$bw_data" | sed 's/^.*bw (/bw (/' | awk -F "," '{print $4}' | cut -d "=" -f2 | tail -1)
	stdev=$(echo "$bw_data" | sed 's/^.*bw (/bw (/' | awk -F "," '{print $5}' | cut -d "=" -f2 | tail -1)

	echo "Units: $units"
	case "$units" in
		MB)
		    avg=$(echo "$avg * 1024" | bc -l)
		    ;;
		GB)
		    avg=$(echo "($avg * 1024) * 1024" | bc -l)
		    ;;
		esac

	save_results "$TEST_NAME" "$TEST_ARGS" "$avg" "KB/s"
	echo "$avg KB/s"
}

function main()
{
	cmds=("bc" "awk" "smem")
	local OPTIND
	while getopts "b:e:hs:o:n:r:t:T:u:x:" opt;do
		case ${opt} in
		b)
		    BLOCK_SIZE="${OPTARG}"
		    ;;
		e)
		    ENGINE="${OPTARG}"
		    ;;
		h)
		    help
		    exit 0;
		    ;;
		s)
		    FILE_SIZE="${OPTARG}"
		    ;;
		o)
		    OPERATION="${OPTARG}"
		    ;;
		n)
		    NUM_JOBS="${OPTARG}"
		    ;;
		r)
		    RUNTIME="${OPTARG}"
		    ;;
		t)
		    TEST_NAME="${OPTARG}"
		    ;;
		T)
		    TEST_TIME="${OPTARG}"
		    ;;
		u)
		    RAMP_TIME="${OPTARG}"
		    ;;
		x)
		    EXTRA_ARGS="${OPTARG}"
		    ;;
		esac
	done
	shift $((OPTIND-1))

	init_env
	check_cmds "${cmds[@]}"
	check_images "$FIO_IMAGE"
	create_fio_run_job
	create_fio_prep_job

	# Check the runtime in order to determine which process will
	# be measured
	if [ "$RUNTIME" == "runc" ]; then
		PROCESS="fio"
	elif [ "$RUNTIME" == "cor" ] || [ "$RUNTIME" == "cc-runtime" ]; then
		PROCESS=${QEMU_PATH}
	else
		die "Unknown runtime: $RUNTIME"
	fi

	# First we set up the container
	CONTAINER_ID=$(docker run -tid --runtime="$RUNTIME" "$FIO_IMAGE" tail -f /dev/null)

	# Now we run the prep task
	docker exec ${CONTAINER_ID} bash -c "$FIO_PREP_JOB"

	# Kick off background tasks to measure the CPU, PSS and RSS
	cpu_temp=$(mktemp fio_job_cpu.XXX)
	pss_temp=$(mktemp fio_job_pss.XXX)
	rss_temp=$(mktemp fio_job_rss.XXX)

	# Obtain volume name
	volume_inspect=$(docker inspect -f '{{ json .Mounts }}' ${CONTAINER_ID})
	volume_name=$(echo $volume_inspect | grep Name | cut -f3 -d ':' | cut -f2 -d '"')

	# We know the test will run for 30s (unless somebody changed it...)
	# So spread the measures out over the test run
	# But, fio will also terminate some tests when it has 'completed the file', rather
	# than obey the time measure it seems (like randwrite) - so on 'fast' systems the
	# runtime can be pretty short - thus, take the measurements a short way into the
	# test.
	(sleep 3; ps --no-headers -o %cpu -C $(basename ${PROCESS}) > ${cpu_temp})&
	(sleep 4; sudo smem -H -P "^${PROCESS}" -c "pss" > ${pss_temp})&
	(sleep 5; sudo smem -H -P "^${PROCESS}" -c "rss" > ${rss_temp})&

	# Drop the host page cache
	sudo bash -c "echo 3>/proc/sys/vm/drop_caches"

	# Finally Launch container
	output=$(docker exec ${CONTAINER_ID} bash -c "$FIO_RUN_JOB")

	# Clean up our container
	docker stop ${CONTAINER_ID}
	docker rm ${CONTAINER_ID}

	# Parse results
	parse_fio_results "$output"

	cpu_val=$(awk '{ total += $1 } END { print total }' < ${cpu_temp})
	save_results "$TEST_NAME"_cpu "$TEST_ARGS" "$cpu_val" "%"
	pss_val=$(awk '{ total += $1} END { print total }' < ${pss_temp})
	save_results "$TEST_NAME"_pss "$TEST_ARGS" "$pss_val" "KB"
	rss_val=$(awk '{ total += $1 } END { print total }' < ${rss_temp})
	save_results "$TEST_NAME"_rss "$TEST_ARGS" "$rss_val" "KB"

	rm ${cpu_temp}
	rm ${pss_temp}
	rm ${rss_temp}

	docker volume rm ${volume_name}
}

main "$@"
