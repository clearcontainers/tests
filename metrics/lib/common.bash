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

SCRIPT_PATH=$(dirname $(readlink -f $0))
RESULT_DIR="${SCRIPT_PATH}/../results"
LIB_DIR="${SCRIPT_PATH}/../lib"

# Set variables to reasonable defaults if unset or empty
DOCKER_EXE="${DOCKER_EXE:-docker}"
RUNTIME="${RUNTIME:-cc-runtime}"
CC_SHIM_PATH="${CC_SHIM_PATH:-/usr/libexec/clear-containers/cc-shim}"
CC_PROXY_PATH="${CC_PROXY_PATH:-/usr/libexec/clear-containers/cc-proxy}"

# If we fail for any reason, exit through here and we should log that to the correct
# place and return the correct code to halt the run
die(){
	msg="$*"
	echo "ERROR: $msg" >&2
	exit 1
}

# Sometimes we just want to warn about something - let's have a standard
# method for that, so maybe we can make a standard form that can be searched
# for in the logs/tooling
warning(){
	msg="$*"
	echo "WARNING: $msg" >&2
}

# Save a test/metric result.
# This is a wrapper function to the send_results.sh command, which ultimately decides
# where and in what format to store or process the data.
# Arguments:
#  Test name
#  Test arguments
#  Test result
#  Test result unit of measurement
function save_results(){
	if [ $# != 4 ]; then
		die "save_results() requires 4 parameters, not $#"
	fi

	bash $LIB_DIR/send_results.sh -n "$1" -a "$2" -r "$3" -u "$4"
}

# This function checks existence of commands.
# They can be received standalone or as an array, e.g.
#
# cmds=(“cmd1” “cmd2”)
# check_cmds "${cmds[@]}"
function check_cmds()
{
	local cmd req_cmds=( "$@" )
	for cmd in "${req_cmds[@]}"; do
		if ! command -v "$cmd" > /dev/null 2>&1; then
			die "command $cmd not available"
			exit 1;
		fi
		echo "command: $cmd: yes"
	done
}

# This function performs a docker pull on the image names
# passed in (notionally as 'about to be used'), to ensure
#  - that we have the most upto date images
#  - that any pull/refresh time (for a first pull) does not
#    happen during the test itself.
#
# The image list can be received standalone or as an array, e.g.
#
# images=(“img1” “img2”)
# check_imgs "${images[@]}"
function check_images()
{
	local img req_images=( "$@" )
	for img in "${req_images[@]}"; do
		echo "docker pull'ing: $img"
		if ! docker pull "$img"; then
			die "Failed to docker pull image $img"
			exit 1;
		fi
		echo "docker pull'd: $img"
	done
}

# A one time (per uber test cycle) init that tries to get the
# system to a 'known state' as much as possible
function onetime_init()
{
	# The onetime init must be called once, and only once
	if [ ! -z "$onetime_init_done" ]; then
		die "onetime_init() called more than once"
	fi

	# Restart services
	sudo systemctl restart docker
	if [[ "${RUNTIME}" == "cor" || "${RUNTIME}" == "cc-runtime" ]];then
		sudo systemctl restart cc-proxy
	fi

	# We want this to be seen in sub shells as well...
	# otherwise init_env() cannot check us
	export onetime_init_done=1
}

# Print a clear banner to the logs noting clearly which test
# we are about to run
function test_banner()
{
	echo -e "\n===== starting test [$1] ====="
}

# Initialization/verification environment. This function makes
# minimal steps for metrics/tests execution.
function init_env()
{
	test_banner "${TEST_NAME}"

	cmd=("docker")

	# check dependencies
	check_cmds "${cmd[@]}"

	# Remove all stopped containers
	clean_env

	# This clean up is more aggressive, this is in order to
	# decrease the factors that could affect the metrics results.
	kill_processes_before_start
}

# Clean environment, this function will try to remove all
# stopped/running containers, it is advisable to use this function
# in the final of each metrics test.
function clean_env()
{
	containers_running=$(docker ps -q)

	if [ ! -z "$containers_running" ]; then
		# First stop all containers that are running
		sudo $DOCKER_EXE stop $containers_running

		# Remove all containers
		sudo $DOCKER_EXE rm -f $(docker ps -qa)
	fi
}

function get_hypervisor_from_toml(){
	## Regular expressions used for TOML parsing
	# Matches a section header
	section_re="^\s*\[(\S+)]"
	# Matches the name of the hypervisor section
	hypervisor_re="^hypervisor(\..*)?"
	# Matches the variable containing the qemu path
	qemu_re="^\s*path\s*=\s*\"([^\"]+)"

	# Case insensitive
	shopt -s nocasematch

	for line in "$@"; do
		if [[ $line =~ $section_re ]]; then
			# New section
			section=${BASH_REMATCH[1]}
		elif [[ $section =~ $hypervisor_re ]]; then
			# Look for qemu path
			if [[ $line =~ $qemu_re ]]; then
				# Found it
				qemu_path="${BASH_REMATCH[1]}"
				echo "${qemu_path}"
				break;
			fi
		fi
	done
}

# Find a reasonable path to the hypervisor on this system
function get_qemu_path(){
	# Create a list of potential configuration files
	declare -a conf_files

	# Use cc-env, if available
	CC_RUNTIME=$(command -v cc-runtime)
	if [[ $? -eq 0 ]] && [[ -n ${CC_RUNTIME} ]]; then
		cc_env_tmp=$(mktemp cc-env.XXXX)
		${CC_RUNTIME} cc-env > "${cc_env_tmp}"
		conf_files+=("${cc_env_tmp}")
	fi

	# Search for other configuration files
	conf_files+=("${LIB_DIR}/../../../runtime/config/configuration.toml")
	conf_files+=($(find /etc -type f -name configuration.toml -exec \
		grep -l 'hypervisor.qemu' {} + 2>/dev/null))

	# Check the potential files sequentially
	for conf_file in "${conf_files[@]}"; do
		[[ -f "${conf_file}" ]] || continue

		# Attempt to parse the found config file (TOML)
		declare -a config
		while read line; do
			config+=("$line")
		done < "${conf_file}"
		qemu_path=$(get_hypervisor_from_toml "${config[@]}")

		# Got one?
		[[ -n "${qemu_path}" ]] || continue;
		[[ -x "${qemu_path}" ]] && break;
	done

	# Cleanup
	[[ -n "${cc_env_tmp}" ]] && rm "${cc_env_tmp}"

	# Check whether we got a good result
	[[ -n "$qemu_path" ]] || die Failed to find qemu path in $conf_file
	[[ -f "$qemu_path" ]] || die "$qemu_path does not exist"
	[[ -x "$qemu_path" ]] || die "$qemu_path is not executable"

	echo "$qemu_path"
}

# Checking that selected runtime is appropriate
function runtime_docker(){
	local found
	local runtimes=($(${DOCKER_EXE} info 2>/dev/null | grep "^Runtimes" \
		| cut -d: -f2))
	for runtime in ${runtimes[@]}; do
		if [[ "${RUNTIME}" == "${runtime}" ]]; then
			found=1
			break;
		fi
	done
	if [[ ! $found ]]; then
		die "Selected runtime ${RUNTIME} not installed in docker (currently: ${runtimes[@]})"
	fi
}

function check_active_process() {
	process=$1
	if pgrep -f "$process" > /dev/null; then
		echo "1"
	else
		echo "0"
	fi
}

# This function checks if there are containers or
# cc-shim and qemu-lite processes up, if found, they are
# killed to start test with clean environment.
function kill_processes_before_start() {
	DOCKER_PROCS=$(${DOCKER_EXE} ps -q)
	[[ -n "${DOCKER_PROCS}" ]] && "${DOCKER_EXE}" kill ${DOCKER_PROCS}

	HYPERVISOR_PATH="$(get_qemu_path)"
	result=$(check_active_process "$HYPERVISOR_PATH")
	if [[ $result -ne 0 ]]; then
		warning "Found unexpected ${HYPERVISOR_PATH} processes present"
		# Sometimes we race and the process has gone by the time we list
		# it - so make a pgrep fail non-fatal
		pgrep -a -f "$HYPERVISOR_PATH" || true
		sudo killall -9 "${HYPERVISOR_PATH##*/}" || true
	fi

	result=$(check_active_process "$CC_SHIM_PATH")
	if [[ $result -ne 0 ]]; then
		warning "Found unexpected ${CC_SHIM_PATH} processes present"
		pgrep -a -f "$CC_SHIM_PATH" || true
		sudo killall -9 "${CC_SHIM_PATH##*/}" || true
	fi
}

# This function checks if active processes were
# left behind by cc-runtime.
function check_processes() {
	process=$1
	pgrep -f "$process"
	if [ $? -eq 0 ]; then
		echo "Found unexpected ${process} present"
		ps -ef | grep $process
		return 1
	fi
}

# Generate a random name - generally used when creating containers, but can
# be used for any other appropriate purpose
function random_name() {
	mktemp -u cc-XXXXXX
}
