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

# If we fail for any reason, exit through here and we should log that to the correct
# place and return the correct code to halt the run
die(){
        msg="$*"
        echo "ERROR: $msg" >&2
        exit 1
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
