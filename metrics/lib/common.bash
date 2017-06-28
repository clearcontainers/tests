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

