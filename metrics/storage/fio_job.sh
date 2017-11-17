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

# This docker image includes FIO tool.
FIO_IMAGE="clusterhq/fio-tool"

# The FIO tool included in clusterhq/fio-tool docker image
# works in "/tmp" by default. "/tmp" is overridden by /home
# mount point in order to avoid tmpfs and use the disk.
FILE_NAME="/home/fio_test"

declare FIO_JOB

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
        -x,    Extra fio arguments.
EOF
)
	echo "$usage"
}

# Create the job configuration for FIO
# this job will run inside of the container.
function create_fio_job()
{
	FIO_JOB="$(cat << EOF
	#!/bin/bash
	# This fio job will run inside of
	# the container.

	fio --ioengine="$ENGINE" \
		--name="$FIO_TEST_NAME" \
		--filename="$FILE_NAME" \
		--bs="$BLOCK_SIZE" \
		--size="$FILE_SIZE" \
		--readwrite="$OPERATION" --max-jobs=$NUM_JOBS \
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

	units=$(echo "$bw_data" grep "bw (" | grep -o "[A-Z]*")
	avg=$(echo "$bw_data" | awk -F "," '{print $4}' | cut -d "=" -f2)
	stdev=$(echo "$bw_data" | awk -F "," '{print $5}' | cut -d "=" -f2)

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
	cmds=("bc" "awk")
	local OPTIND
	while getopts "b:e:hs:o:n:r:t:x:" opt;do
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
		x)
		    EXTRA_ARGS="${OPTARG}"
		    ;;
		esac
	done
	shift $((OPTIND-1))

	init_env
	check_cmds "${cmds[@]}"
	create_fio_job

	# Launch container
	output=$(docker run --rm --runtime="$RUNTIME" \
		"$FIO_IMAGE" bash -c "$FIO_JOB")

	# Parse results
	parse_fio_results "$output"
}

main "$@"
