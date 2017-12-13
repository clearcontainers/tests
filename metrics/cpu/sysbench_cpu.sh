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
#   This test runs the 'sysbench cpu' test in a container, and extracts
#   the '95 percentile' result from the output

set -e

# General env
SCRIPT_PATH=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_PATH}/../lib/common.bash"
TEST_ARGS="$@"

# These values are a basic configuration for a FIO job
# execution, however they could be overridden in order to
# run a customized FIO job.
TEST_NAME="sysbench cpu"

# This docker image includes FIO tool.
IMAGE="local-sysbench"
DOCKERFILE="${SCRIPT_PATH}/../../Dockerfiles/sysbench"
CMD="sysbench --test=cpu run"

# Check if we have our local image installed, and if not, install it
# from the dockerfile
function local_check_images()
{
	local exists=$(docker image inspect $IMAGE > /dev/null; echo $?)

	if [ $exists -ne 0 ]; then
		docker build --label "$IMAGE" --tag "${IMAGE}:latest" "$DOCKERFILE"
	fi
}

function main()
{
	cmds=("awk")

	init_env
	check_cmds "${cmds[@]}"
	local_check_images "$IMAGE"

	# Now we run the prep task
	local output=$(docker run --rm $IMAGE $CMD)

	declare -a ir
	local ir=($(fgrep percentile <<< "$output" | awk '{print $4}' | sed 's/\([0-9.]*\)\(.*\)/\1 \2/'))
	local result=${ir[0]}
	local units=${ir[1]}

	save_results "$TEST_NAME" "$CMD" "$result" "$units"
}

main "$@"
