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

CURRENTDIR=$(dirname "$(readlink -f "$0")")
REPORT_CMDS=("checkmetrics" "emailreport")

# Verify/install report tools. These tools will
# parse/send the results from metrics scripts execution.
for cmd in "${REPORT_CMDS[@]}"; do
	if ! command -v "$cmd" > /dev/null 2>&1; then
		pushd "$CURRENTDIR/../cmd/$cmd"
		make
		make install
		popd
	fi
done

# Execute metrics scripts and report the results
# by email.
pushd "$CURRENTDIR/../metrics"
	source "lib/common.bash"

	# Run the time tests
	bash time/docker_workload_time.sh true busybox $RUNTIME 100

	# Parse/Report results
	emailreport

	# Clean env
	rm -rf "results"
popd

exit 0
