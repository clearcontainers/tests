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
source /etc/os-release
start_test="$(date '+%Y-%m-%d %H:%M:%S')"
last_test="${start_test}"

function cleanup {
	if (( "$?" != 0 )); then
		echo "DEBUG: Logs from all test "
		sudo journalctl -t cc-runtime  --since="${start_test}" --no-pager
		if [ "${start_test}" != "${last_test}" ]; then
			echo "DEBUG: Logs from last test"
			sudo journalctl -t cc-runtime  --since="${last_test}" --no-pager
		fi
	fi
}

trap cleanup EXIT

if [ "$ID" == "ubuntu" ] && [ "$VERSION_ID" == "17.04" ]; then
	export CRIO_STORAGE_DRIVER_OPTS="--storage-driver=devicemapper"
fi

sudo -E PATH="$PATH" bash -c "make check"

# Currently, Openshift tests only work on Fedora.
# We should delete this condition, when it works for Ubuntu.
if [ "$ID" == fedora  ]; then
	last_test=$(date '+%Y-%m-%d %H:%M:%S')
	sudo -E PATH="$PATH" bash -c "make openshift"
fi

#FIXME: Running swarm before openshift breaks cc-runtime list
# see https://github.com/clearcontainers/runtime/issues/902
last_test=$(date '+%Y-%m-%d %H:%M:%S')
sudo -E PATH="$PATH" bash -c "make swarm"
