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
#  This test measures the complete workload of a container using docker.
#  From calling docker until the workload is completed and the container
#  is shutdown.

set -e

[ $# -ne 4 ] && ( echo >&2 "Usage: $0 <cmd to run> <image> <runtime> <times to run>"; exit 1 )

SCRIPT_PATH=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_PATH}/../lib/common.bash"

CMD="$1"
IMAGE="$2"
RUNTIME="$3"
TIMES="$4"
TMP_FILE=$(mktemp workloadTime.XXXXXXXXXX || true)
TEST_NAME="docker run time"
TEST_ARGS="image=${IMAGE} command=${CMD} runtime=${RUNTIME} units=seconds"
TEST_RESULT_FILE=$(echo "${RESULT_DIR}/${TEST_NAME}-${IMAGE}-${CMD}-${RUNTIME}" | sed 's| |-|g')

# Ensure we have yanked down the necessary images before we begin - we do not
# want to be adding that overhead into any of our measurement times
function prewarm(){
	echo Pre-warming by pulling $IMAGE
	docker pull $IMAGE
}

function run_workload(){
	# temporarily unset 'e' as we want to carry on to report if this fails.
	# but set it in the subshell, as we'd like the docker command to fail and bail , rather than
	# have the 'time' pass, but report how long it took for docker to fail.
	set +e
	(set -e; time -p docker run --rm --runtime "$RUNTIME" "$IMAGE" "$CMD") &> "$TMP_FILE"
	set -e

	test_data=$(grep ^real "$TMP_FILE" | cut -f2 -d' ')

	# if the test failed then we will fail to find the '^real' data value - so
	# error out and try to log what we can
	if [ -z "$test_data" ];then
		echo "docker workload test failed. Dumping logs..."
		echo "--------log file-------------"
		cat $TMP_FILE
		echo "--------end of log file-------------"
		rm -f $TMP_FILE
		die "Failed to execute test 'docker run --rm --runtime "$RUNTIME" "$IMAGE" "$CMD"'"

	fi

	save_results "$TEST_NAME" "$TEST_ARGS" "$test_data" "s"
	rm -f $TMP_FILE
}

init_env
prewarm
for i in $(seq 1 "$TIMES"); do
	run_workload
done
