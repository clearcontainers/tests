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

set -e

SCRIPT_PATH=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_PATH}/crio_skip_tests.sh"
source "${SCRIPT_PATH}/../../.ci/lib.sh"
get_cc_versions

crio_repository="github.com/kubernetes-incubator/cri-o"
check_crio_repository="$GOPATH/src/${crio_repository}"

if [ -d ${check_crio_repository} ]; then
	pushd ${check_crio_repository}
	check_version=$(git status | grep "${crio_version}")
	if [ $? -ne 0 ]; then
		git fetch
		git checkout "${crio_version}"
	fi
	popd
else
	echo "Obtain CRI-O repository"
	go get -d "${crio_repository}" || true
	pushd ${check_crio_repository}
	git fetch
	git checkout "${crio_version}"
	popd
fi

OLD_IFS=$IFS
IFS=''

# Skip CRI-O tests that currently are not working
pushd $GOPATH/src/${crio_repository}/test/
for i in ${skipCRIOTests[@]}
do
	sed -i '/'${i}'/a skip \"This is not working (Issue https://github.com/clearcontainers/tests/issues/943)\"' "$GOPATH/src/${crio_repository}/test/ctr.bats"
done

IFS=$OLD_IFS

bats ctr.bats
popd
