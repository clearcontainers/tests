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

set -eE

# Runtime to be used for testing.
RUNTIME=${RUNTIME:-cc-runtime}
# Variable to change project to test (eg. kata or clear-contaienrs)
PROJECT_ORG="${PROJECT:-clear-containers}"
readonly runtime_bin=$(command -v "${RUNTIME}")

#cri-containerd configuration test variables
CRITEST=${GOPATH}/bin/critest

#containerd config fileo
readonly tmp_dir=$(mktemp -t -d test-cri-containerd.XXXX)
export REPORT_DIR="${tmp_dir}"
CONTAINERD_CONFIG_FILE="${tmp_dir}/test-containerd-config"


info() {
	echo -e "\e[1mINFO\e[0m: $*"
}


cleanup() {
	rm -rf "${tmp_dir}"
}

err_report() {
	echo "ERROR: contaienrd log :"
	echo "-------------------------------------"
	cat "${REPORT_DIR}/containerd.log"
	echo "-------------------------------------"
}

trap err_report ERR
trap cleanup EXIT

info "Stop crio service"

sudo systemctl stop crio

info "testing using runtime: ${runtime_bin}"

# make sure cri-containerd test install the proper installation for testing
rm -f "${CRITEST}"


cri_containerd_repo="github.com/containerd/cri"

pushd "${GOPATH}/src/${cri_containerd_repo}"
cat > "${CONTAINERD_CONFIG_FILE}" << EOT
[plugins]
  [plugins.cri]
    [plugins.cri.containerd]
      [plugins.cri.containerd.default_runtime]
        runtime_engine = "${runtime_bin}"
EOT

info "Starting test for cri-tools"
sudo -E PATH="${PATH}" \
	FOCUS="runtime should support basic operations on container" \
	REPORT_DIR="${REPORT_DIR}" \
	CONTAINERD_CONFIG_FILE="$CONTAINERD_CONFIG_FILE" \
	make test-cri

info "Starting test for test-integration"

passing_test=(
                TestClearContainersCreate
                TestContainerStats
                TestContainerListStatsWithIdFilter
                TestContainerListStatsWithSandboxIdFilterd
                TestContainerListStatsWithIdSandboxIdFilter
                TestDuplicateName
                TestImageLoad
                TestImageFSInfo
                TestSandboxCleanRemove
             )

for t in "${passing_test[@]}"
do
sudo -E PATH="${PATH}" \
	REPORT_DIR="${REPORT_DIR}" \
	FOCUS="${t}" \
	CONTAINERD_CONFIG_FILE="$CONTAINERD_CONFIG_FILE" \
	make test-integration
done

popd
