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

# Setup workflow:
# 1. setup environment (install qemu, kernel and image)
# 2. Clone repos, fetch branches, build and install

set -e

cidir=$(dirname "$0")
source /etc/os-release

echo "Set up environment"
if [ "$ID" == fedora ];then
	bash -f "${cidir}/setup_env_fedora.sh"
elif [ "$ID" == ubuntu ];then
	bash -f "${cidir}/setup_env_ubuntu.sh"
fi

# This should only run when running tests for a PR
# since it looks for PULL_REQUEST_NUMBER or LOCALCI_PR_NUMBER environment
# variable.
if [ -n "$PULL_REQUEST_NUMBER" ] || [ -n "$LOCALCI_PR_NUMBER" ]; then
	echo "Building and running the fetch branches tool"
	bash -f "${cidir}/run_fetch_branches_tool.sh"
fi

echo "Install shim"
bash -f ${cidir}/install_shim.sh

echo "Install proxy"
bash -f ${cidir}/install_proxy.sh

echo "Install runtime"
bash -f ${cidir}/install_runtime.sh

echo "Install CNI plugins"
bash -f ${cidir}/install_cni_plugins.sh

echo "Install CRI-O"
bash -f ${cidir}/install_crio.sh

bash -f "${cidir}/openshift_setup.sh"

echo "Drop caches"
sync
sudo -E PATH=$PATH bash -c "echo 3 > /proc/sys/vm/drop_caches"
