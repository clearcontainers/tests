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

set -e

SCRIPT_PATH=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_PATH}/lib/common.bash"

# Check arguments
if [[ ! -v RUNTIME ]]; then
    die Variable RUNTIME must be set to the name of your CC runtime
fi

SCRIPT_PATH=$(dirname "$(readlink -f "$0")")

echo "Running all metrics tests"

# Run the time tests
bash ${SCRIPT_PATH}/time/docker_workload_time.sh true busybox $RUNTIME 100

# Run the network metrics
bash ${SCRIPT_PATH}/network/network-latency.sh
