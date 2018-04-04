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
cidir=$(dirname "$0")
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

MAJOR=$(echo "$VERSION_ID"|cut -d\. -f1)

# Only use devicemapper for Ubuntu 17.* and newer.
if [ "$ID" == "ubuntu" ] && [ "$MAJOR" -ge 17 ]; then
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

last_test=$(date '+%Y-%m-%d %H:%M:%S')
#TODO <carlos>: cri-o and k8s are in 1.9
#If install cri-containerd will upgrade crictl to 1.10 and will break k8s/kubaadm.
#Lets install an run the test after run k8s tests
echo "Install cri-containerd"
bash -f ${cidir}/install_cri_containerd.sh
sudo -E PATH="$PATH" bash -c "make cri-containerd"
