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
bash ${SCRIPT_PATH}/network/network-metrics-cpu-consumption.sh
bash ${SCRIPT_PATH}/network/network-metrics-iperf3.sh
bash ${SCRIPT_PATH}/network/network-metrics-memory-pss-1g.sh
bash ${SCRIPT_PATH}/network/network-metrics-memory-pss.sh
bash ${SCRIPT_PATH}/network/network-metrics-memory-rss-1g.sh
bash ${SCRIPT_PATH}/network/network-metrics-nuttcp.sh
bash ${SCRIPT_PATH}/network/network-metrics.sh
bash ${SCRIPT_PATH}/network/network-nginx-ab-benchmark.sh

# Run the density/footprint scripts
# If you have KSM enabled, the 'settle time' depends on the default settings.
# For instance, for an Ubuntu 16.04 default install, it takes about 200s for
# 20 CC containers footprint to 'settle down'.
#
# Presume KSM is off, and hence no need to have a settle time
bash ${SCRIPT_PATH}/density/docker_memory_usage.sh 20 1

# Run I/O storage tests
bash storage/fio_job.sh -b 16k -o randread -t "storage IO random read bs 16k"
bash storage/fio_job.sh -b 16k -o randwrite -t "storage IO random write bs 16k"
bash storage/fio_job.sh -b 16k -o read -t "storage IO linear read bs 16k"
bash storage/fio_job.sh -b 16k -o write -t "storage IO linear write bs 16k"
