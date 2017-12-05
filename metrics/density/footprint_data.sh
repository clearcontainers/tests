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

# A script to gather memory 'footprint' information as we launch more
# and more containers
# It allows configuration of a number of things:
# - which container workload we run
# - which container runtime we run with
# - when do we terminate the test (cutoff points)
#
# There are a number of things we may wish to add to this script later:
# - allow configuration of the amount of memory passed to each container
# - sanity check that the correct number of runtime components (qemu, shim etc.)
#  are running at all times
# - clean up better after ourselves (that will be fixed in the generic lib files...)
# - some post-processing scripts to generate stats and graphs
#
# The script gathers information about both user and kernel space consumption
# Output is into a .csv file, named using some of the config component names
# (such as results-cc-runtime-busybox.csv)

# Pull in some common, useful, items
SCRIPT_PATH=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_PATH}/../lib/common.bash"

# Note that all vars that can be set from outside the script (that is,
# passed in the ENV), use the ':-' setting to allow being over-ridden

### The default config - run a small busybox image
# Define what we will be running (app under test)
#  Default is we run busybox, as a 'small' workload
PAYLOAD="${PAYLOAD:-busybox}"
PAYLOAD_ARGS="${PAYLOAD_ARGS:-tail -f /dev/null}"
PAYLOAD_RUNTIME_ARGS="${PAYLOAD_RUNTIME_ARGS:-}"


#########################
### Below are a couple of other examples of workload configs:
#  mysql is a more medium sized workload
#PAYLOAD="${PAYLOAD:-mysql}"
# Disable the aio use, or you can only run ~24 containers under runc, as you run out
# of handles in the kernel.
#PAYLOAD_ARGS="${PAYLOAD_ARGS:- --innodb_use_native_aio=0}"
#PAYLOAD_RUNTIME_ARGS="${PAYLOAD_RUNTIME_ARGS:-'-e MYSQL_ALLOW_EMPTY_PASSWORD=1'}"
#
#  elasticsearch is a large workload
#PAYLOAD="${PAYLOAD:-elasticsearch}"
#PAYLOAD_ARGS="${PAYLOAD_ARGS:-}"
#PAYLOAD_RUNTIME_ARGS="${PAYLOAD_RUNTIME_ARGS:-}"
#########################

###
# which RUNTIME we use is picked up from the env in
# common.bash. You can over-ride by setting RUNTIME in your env

###
# Define the cutoff checks for when we stop running the test
  # Run up to this many containers
MAX_NUM_CONTAINERS="${MAX_NUM_CONTAINERS:-20}"
  # Run until we have consumed this much memory (from MemFree)
MAX_MEMORY_CONSUMED="${MAX_MEMORY_CONSUMED:-6*1024*1024*1024}"
  # Run until we have this much MemFree left
MIN_MEMORY_FREE="${MIN_MEMORY_FREE:-2*1024*1024*1024}"

# Proxy and shim paths come from common.bash
# You can over-ride them in your env
#CC_PROXY_PATHPROXY
#CC_SHIM_PATH
# Use the magic in common.bash to find the correct QEMU path
CC_QEMU_PATH="${CC_QEMU_PATH:-get_qemu_path}"

# We monitor dockerd as we know it can grow as we run containers
DOCKERD_PATH="${DOCKERD_PATH:-/usr/bin/dockerd}"

# Tools we need to have installed in order to operate
REQUIRED_COMMANDS="smem awk"

# If we 'dump' the system caches before we measure then we get less
# noise in the results - they show more what our un-reclaimable footprint is
DUMP_CACHES="${DUMP_CACHES:-1}"

# The name of the file to store the results in
DATAFILE="${DATAFILE:-results-${RUNTIME}-${PAYLOAD}.csv}"

############# end of configurable items ###################

# vars to remember where we started so we can calc diffs
base_mem_avail=0
base_mem_free=0

# dump the kernel caches, so we get a more precise (or just different)
# view of what our footprint really is.
function dump_caches() {
	sudo bash -c "echo 3 > /proc/sys/vm/drop_caches"
}

function init() {
	check_cmds $REQUIRED_COMMANDS
	check_images "$PAYLOAD"
	# Use the common init func to get to a known state
	init_env

	# Set the first column header in the results
	echo -n "number" > $DATAFILE

	# And ask the capture funcs to put their headers in the results file
	DUMP_HEADER=1
	grab_stats
	DUMP_HEADER=

	# and terminate that line...
	echo "" >> $DATAFILE
}

function cleanup() {
	# This is what we have for now from the generics.
	# Expect this to be improved (the generics) soon...
	kill_processes_before_start
}

# helper function to get USS of prcess in arg1
function get_proc_uss() {
	item=$(sudo smem -t -P "^$1" | tail -1 | awk '{print $4}')
	((item*=1024))
	echo $item
}

# helper function to get PSS of prcess in arg1
function get_proc_pss() {
	item=$(sudo smem -t -P "^$1" | tail -1 | awk '{print $5}')
	((item*=1024))
	echo $item
}

# Get the USS footprint of the CC runtime components
function grab_cc_uss() {
	if [[ $DUMP_HEADER ]]; then
		echo -n ", cc_uss" >> $DATAFILE
		return
	fi

	proxy=$(get_proc_uss $CC_PROXY_PATH)
	shim=$(get_proc_uss $CC_SHIM_PATH)
	qemu=$(get_proc_uss $CC_QEMU_PATH)

	total=$((proxy + shim + qemu))
	echo -n ", $total" >> $DATAFILE
}

# Get the PSS footprint of the CC runtime components
function grab_cc_pss() {
	if [[ $DUMP_HEADER ]]; then
		echo -n ", cc_pss" >> $DATAFILE
		return
	fi

	proxy=$(get_proc_pss $CC_PROXY_PATH)
	shim=$(get_proc_pss $CC_SHIM_PATH)
	qemu=$(get_proc_pss $CC_QEMU_PATH)

	total=$((proxy + shim + qemu))
	echo -n ", $total" >> $DATAFILE
}

# Get the PSS footprint of dockerd - we know it can
# grow in size as we launch containers, so let's try to
# account for it
function grab_dockerd_pss() {
	if [[ $DUMP_HEADER ]]; then
		echo -n ", dockerd_pss" >> $DATAFILE
		return
	fi

	item=$(get_proc_pss $DOCKERD_PATH)
	echo -n ", $item" >> $DATAFILE
}

# Get the PSS for the whole of userspace (all processes)
#  This allows us to see if we had any impact on the rest of the system, for instance
#  dockerd grows as we launch containers, so we should account for that in our total
#  memory breakdown
function grab_all_pss() {
	if [[ $DUMP_HEADER ]]; then
		echo -n ", all_pss" >> $DATAFILE
		return
	fi

	item=$(sudo smem -t | tail -1 | awk '{print $5}')
	((item*=1024))
	echo -n ", $item" >> $DATAFILE
}

function grab_user_smem() {
	if [[ $DUMP_HEADER ]]; then
		echo -n ", user" >> $DATAFILE
		return
	fi

	# userspace
	item=$(sudo smem -w | head -5 | tail -1 | awk '{print $3}')
	((item*=1024))
	echo -n ", $item" >> $DATAFILE
}

function grab_slab() {
	if [[ $DUMP_HEADER ]]; then
		echo -n ", slab" >> $DATAFILE
		return
	fi

	# Grabbing slab total from meminfo is easier than doing the math
	# on slabinfo
	item=$(fgrep "Slab:" /proc/meminfo | awk '{print $2}')
	((item*=1024))
	echo -n ", $item" >> $DATAFILE
}

function get_memfree() {
	mem_free=$(sudo smem -w | head -6 | tail -1 | awk '{print $4}')
	((mem_free*=1024))
	echo $mem_free
}

function grab_system() {
	if [[ $DUMP_HEADER ]]; then
		echo -n ", avail" >> $DATAFILE
		echo -n ", avail_incr" >> $DATAFILE
		echo -n ", cached" >> $DATAFILE
		echo -n ", free_smem" >> $DATAFILE
		echo -n ", free_smem_incr" >> $DATAFILE
		echo -n ", anon_pages" >> $DATAFILE
		echo -n ", mapped_pages" >> $DATAFILE
		echo -n ", cached" >> $DATAFILE

		# Store up baseline measures
		base_mem_avail=$(free -b | head -2 | tail -1 | awk '{print $7}')
		base_mem_free=$(get_memfree)
		return
	fi

	# avail memory, from 'free'
	item=$(free -b | head -2 | tail -1 | awk '{print $7}')
	echo -n ", $item" >> $DATAFILE
	avail_incr=$((base_mem_avail-item))
	echo -n ", $avail_incr" >> $DATAFILE

	# cached memory, from 'free'
	item=$(free -b | head -2 | tail -1 | awk '{print $6}')
	echo -n ", $item" >> $DATAFILE

	# free memory from smem
	item=$(get_memfree)
	echo -n ", $item" >> $DATAFILE
	free_incr=$((base_mem_free-item))
	echo -n ", $free_incr" >> $DATAFILE

	# Anon pages
	item=$(fgrep "AnonPages:" /proc/meminfo | awk '{print $2}')
	((item*=1024))
	echo -n ", $item" >> $DATAFILE

	# Mapped pages
	item=$(egrep "^Mapped:" /proc/meminfo | awk '{print $2}')
	((item*=1024))
	echo -n ", $item" >> $DATAFILE

	# Cached
	item=$(grep "^Cached:" /proc/meminfo | awk '{print $2}')
	((item*=1024))
	echo -n ", $item" >> $DATAFILE
}

function grab_stats() {
	# If configured, dump the caches so we get a more stable
	# view of what our static footprint really is
	if [[ DUMP_CACHES ]] ; then
		dump_caches
	fi

	# user space data
		# USS taken by CC components
	grab_cc_uss
		# PSS taken all userspace
	grab_cc_pss
		# PSS taken all userspace
	grab_all_pss
		# PSS taken by dockerd
	grab_dockerd_pss
		# user as reported by smem
	grab_user_smem

	# System overview data
		# System free and cached
	grab_system

	# kernel data
		# The 'total kernel space taken' we can work out as:
		# ktotal = ((free-avail)-user)
		# So, we don't grab that number from smem, as that is what it does
		# internally anyhow.
		# Still try to grab any finer kernel details that we can though

		# totals from slabinfo
	grab_slab
}

function check_limits() {
	mem_free=$(get_memfree)
	if ((mem_free <= MIN_MEMORY_FREE)); then
		echo 1
		return
	fi

	mem_consumed=$((base_mem_avail-mem_free))
	if ((mem_consumed >= MAX_MEMORY_CONSUMED)); then
		echo 1
		return
	fi

	echo 0
}

function go() {
	for i in $(seq 1 $MAX_NUM_CONTAINERS); do
		docker run -tid --runtime=$RUNTIME $PAYLOAD_RUNTIME_ARGS $PAYLOAD $PAYLOAD_ARGS

		if [[ $PAYLOAD_SLEEP ]]; then
			sleep $PAYLOAD_SLEEP
		fi

		# prefix data with item number column
		echo -n "$i" >> $DATAFILE
		grab_stats
		# and termnate the line with a CR (and no ',')
		echo "" >> $DATAFILE

		# check if we have hit one of our limits and need to wrap up the tests
		if (($(check_limits))); then
			return
		fi
	done
}


function show_vars()
{
	echo -e "\nEvironment variables:"
	echo -e "\tName (default)"
	echo -e "\t\tDescription"
	echo -e "\tPAYLOAD (${PAYLOAD})"
	echo -e "\t\tThe docker image to run"
	echo -e "\tPAYLOAD_ARGS (${PAYLOAD_ARGS})"
	echo -e "\t\tAny arguments passed into the docker image"
	echo -e "\tPAYLOAD_RUNTIME_ARGS (${PAYLOAD_RUNTIME_ARGS})"
	echo -e "\t\tAny extra arguments passed into the docker 'run' command"
	echo -e "\tPAYLOAD_SLEEP (${PAYLOAD_SLEEP})"
	echo -e "\t\tSeconds to sleep between launch and measurement, to allow settling"
	echo -e "\tMAX_NUM_CONTAINERS (${MAX_NUM_CONTAINERS})"
	echo -e "\t\tThe maximum number of containers to run before terminating"
	echo -e "\tMAX_MEMORY_CONSUMED (${MAX_MEMORY_CONSUMED})"
	echo -e "\t\tThe maximum amount of memory to be consumed before terminating"
	echo -e "\tMIN_MEMORY_FREE (${MIN_MEMORY_FREE})"
	echo -e "\t\tThe minimum amount of memory allowed to be free before terminating"
	echo -e "\tCC_QEMU_PATH (${CC_QEMU_PATH})"
	echo -e "\t\tThe path to the Clear Containers QEMU binary (for 'smem' measurements)"
	echo -e "\tDOCKERD_PATH (${DOCKERD_PATH})"
	echo -e "\t\tThe path to the Docker 'dockerd' binary (for 'smem' measurements)"
	echo -e "\tDUMP_CACHES (${DUMP_CACHES})"
	echo -e "\t\tA flag to note if the system caches should be dumped before capturing stats"
	echo -e "\tDATAFILE (${DATAFILE})"
	echo -e "\t\tCan be set to over-ride the default CSV results filename"

}

function help()
{
	usage=$(cat << EOF
Usage: $0 [-h] [options]
   Description:
	Launch a series of workloads and take memory metric measurements after
	each launch.
   Options:
        -h,    Help page.
EOF
)
	echo "$usage"
	show_vars
}

function main() {

	local OPTIND
	while getopts "h" opt;do
		case ${opt} in
		h)
		    help
		    exit 0;
		    ;;
		esac
	done
	shift $((OPTIND-1))

	init
	go
	cleanup
}

main "$@"

