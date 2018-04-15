#!/bin/bash
#
# Copyright (c) 2017-2018 Intel Corporation
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

# Note - no 'set -e' in this file - if one of the metrics tests fails
# then we wish to continue to try the rest.
# Finally at the end, in some situations, we explicitly exit with a
# failure code if necessary.

CURRENTDIR=$(dirname "$(readlink -f "$0")")
source "${CURRENTDIR}/../metrics/lib/common.bash"

REPORT_CMDS=("checkmetrics" "emailreport")

KSM_BASE="/sys/kernel/mm/ksm"
KSM_ENABLE_FILE="${KSM_BASE}/run"
KSM_PAGES_FILE="${KSM_BASE}/pages_to_scan"
KSM_SLEEP_FILE="${KSM_BASE}/sleep_millisecs"

# The settings we use for an 'aggresive' KSM setup
# Scan 1000 pages every 50ms - 20,000 pages/s
KSM_AGGRESIVE_PAGES=1000
KSM_AGGRESIVE_SLEEP=50

GITHUB_URL="https://github.com"
RESULTS_BACKUP_PATH="/var/local/localCI/backup"
RESULTS_DIR="results"

# Set up the initial state
onetime_init

# Always build and install the latest versions of the tools we need
for cmd in "${REPORT_CMDS[@]}"; do
	pushd "$CURRENTDIR/../cmd/$cmd"
	make
	sudo make install
	popd
done

# Save the current KSM settings so we can restore them later
save_ksm_settings(){
	echo "saving KSM settings"
	ksm_stored_run=$(cat ${KSM_ENABLE_FILE})
	ksm_stored_pages=$(cat ${KSM_ENABLE_FILE})
	ksm_stored_sleep=$(cat ${KSM_ENABLE_FILE})
}

set_ksm_aggressive(){
	echo "setting KSM to aggressive mode"
	# Flip the run off/on to ensure a restart/rescan
	sudo bash -c "echo 0 > ${KSM_ENABLE_FILE}"
	sudo bash -c "echo ${KSM_AGGRESIVE_PAGES} > ${KSM_PAGES_FILE}"
	sudo bash -c "echo ${KSM_AGGRESIVE_SLEEP} > ${KSM_SLEEP_FILE}"
	sudo bash -c "echo 1 > ${KSM_ENABLE_FILE}"
}

restore_ksm_settings(){
	echo "restoring KSM settings"
	# First turn off the run to ensure if we are then re-enabling
	# that any changes take effect
	sudo bash -c "echo 0 > ${KSM_ENABLE_FILE}"
	sudo bash -c "echo ${ksm_stored_pages} > ${KSM_PAGES_FILE}"
	sudo bash -c "echo ${ksm_stored_sleep} > ${KSM_SLEEP_FILE}"
	sudo bash -c "echo ${ksm_stored_run} > ${KSM_ENABLE_FILE}"
}

disable_ksm(){
	echo "disabling KSM"
	sudo bash -c "echo 0 > ${KSM_ENABLE_FILE}"
}

# Execute metrics scripts, save the results and report them
# by email.
pushd "$CURRENTDIR/../metrics"
	source "lib/common.bash"

	# If KSM is available on this platform, let's run the KSM tests first
	# and then turn it off for the rest of the tests, as KSM may introduce
	# some extra noise in the results by stealing CPU time for instance
	if [[ -f ${KSM_ENABLE_FILE} ]]; then
		save_ksm_settings
		trap restore_ksm_settings EXIT QUIT KILL
		set_ksm_aggressive

		# Ensure KSM is enabled
		sudo bash -c "echo 1 > ${KSM_ENABLE_FILE}"

		# Note - here we could set some default settings for KSM,
		# as on some distros KSM may either be set to rather passive
		# which affects the chosen 'settle time' of the tests

		# Run the memory footprint test. With default Ubuntu 16.04
		# settings, and 20 containers, it takes ~200s to 'settle' to
		# a steady memory footprint
		bash density/docker_memory_usage.sh 20 300 auto

		# And now ensure KSM is turned off for the rest of the tests
		sudo bash -c "echo 0 > ${KSM_ENABLE_FILE}"
		disable_ksm
	fi

	# Run the time tests
	bash time/docker_workload_time.sh true busybox $RUNTIME 100

	# Run the memory footprint test
	# As we have no KSM here, we do not need a 'settle delay'
	bash density/docker_memory_usage.sh 20 1

	#
	# Run some network tests
	#

	# ops/second
	bash network/network-nginx-ab-benchmark.sh

	# iperf3 bandwidth between host and container
	bash network/network-metrics-iperf3.sh -B -i 8

	#
	# Run some IO tests
	#
	# Block Size and Ramp Time Settings for Fio Test
	BLOCK_SIZE="16k"
	RAMP_TIME="60"

	bash storage/fio_job.sh -b ${BLOCK_SIZE} -u ${RAMP_TIME} -o randread -t "storage IO random read bs ${BLOCK_SIZE}"
	bash storage/fio_job.sh -b ${BLOCK_SIZE} -u ${RAMP_TIME} -o randwrite -t "storage IO random write bs ${BLOCK_SIZE}"
	bash storage/fio_job.sh -b ${BLOCK_SIZE} -u ${RAMP_TIME} -o read -t "storage IO linear read bs ${BLOCK_SIZE}"
	bash storage/fio_job.sh -b ${BLOCK_SIZE} -u ${RAMP_TIME} -o write -t "storage IO linear write bs ${BLOCK_SIZE}"

	#
	# Run some cpu tests
	#
	bash cpu/sysbench_cpu.sh

	#
	# Run some memory performance tests
	#
	bash memperf/sysbench_memory.sh

	# If we are running under a CI, the do some extra work
	# We check we are under a CI before doing this, as that still leaves us
	# the ability to run this script by hand outside a CI if we need
	if [ -n "${METRICS_CI}" ]; then

		# If we are under LOCALCI, then use emailreport to process the metrics
		# and store the results in a known backup area
		if [ -n "${LOCALCI}" ]; then
			# Pull request URL
			PR_URL="$GITHUB_URL/$LOCALCI_REPO_SLUG/pull/$LOCALCI_PR_NUMBER"

			# Subject for emailreport tool about Pull Request
			SUBJECT="[${LOCALCI_REPO_SLUG}] metrics report (#${LOCALCI_PR_NUMBER})"

			# Parse/Report results
			emailreport -c "Pull request: $PR_URL" -s "$SUBJECT"

			# Save the results directory in a backup path. The metrics tests will be
			# executed each new pull request or when a Pull Request has been modified,
			# then the results from the same Pull Request number will be identified
			# by epoch point time as name of the direcory.
			REPO="$(cut -d"/" -f2 <<<"$LOCALCI_REPO_SLUG")"
			PR_BK_RESULTS="$RESULTS_BACKUP_PATH/$REPO/$LOCALCI_PR_NUMBER"
			DEST="$PR_BK_RESULTS/$(date --iso-8601=seconds)"

			if [ ! -d "$PR_BK_RESULTS" ]; then
				mkdir -p "$PR_BK_RESULTS"
			fi

			mv "$RESULTS_DIR" "$DEST"
		else
			# Not a localCI CI - check the metrics using the checkmetrics
			# tool, utilising a host-specific named config file, and let
			# the pass/fail of checkmetrics dictate the 'outcome' of
			# this script
			checkmetrics --basefile /etc/checkmetrics/checkmetrics-$(uname -n).toml --metricsdir ${RESULTS_DIR}
			cm_result=$?
			if [ ${cm_result} != 0 ]; then
				echo "checkmetrics FAILED (${cm_result})"
				exit ${cm_result}
			fi
		fi
	fi

popd

exit 0
