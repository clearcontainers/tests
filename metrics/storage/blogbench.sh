#!/bin/bash
#
# Copyright (c) 2018 Intel Corporation
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
# This test runs the 'blogbench', and extracts the 'scores' for reads
# and writes
# Note - the scores are *not* normalised for the number of iterations run,
# they are total scores for all iterations (this is the blogbench default output)

set -e

# General env
SCRIPT_PATH=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_PATH}/../lib/common.bash"
TEST_ARGS="$@"

TEST_NAME="blogbench"
IMAGE="local-blogbench"
DOCKERFILE="${SCRIPT_PATH}/../../Dockerfiles/blogbench"

# Number of iterations for blogbench to run - note, results are not
# scaled to iterations - more iterations results in bigger results
ITERATIONS="${ITERATIONS:-10}"

# Directory to run the test on
TESTDIR="${TESTDIR:-/tmp}"
CMD="blogbench -i ${ITERATIONS} -d ${TESTDIR}"

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

	# Run the test...
	local output=$(docker run --rm --runtime=$RUNTIME $IMAGE $CMD)

	local writes=$(tail -2 <<< "$output" | head -1 | awk '{print $5}')
	local reads=$(tail -1 <<< "$output" | awk '{print $6}')

	save_results "$TEST_NAME-writes" "$CMD" "$writes" "items"
	save_results "$TEST_NAME-reads" "$CMD" "$reads" "items"
}

main "$@"
