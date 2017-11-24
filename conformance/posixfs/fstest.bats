#!/usr/bin/env bats
# *-*- Mode: sh -*-*
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
#
# Posix conformance test
#

# Environment variables
DOCKER_EXE="docker"
DEBIAN_IMAGE="debian"
CONT_NAME="fstest"
FSTEST_URL="https://git.code.sf.net/p/ntfs-3g/pjd-fstest"
FSTEST_DIR="/pjd-fstest"
DOCKER_ENV_OPT=""

setup() {
	if [ -n "$http_proxy" ]; then
		DOCKER_ENV_OPT="$DOCKER_ENV_OPT -e http_proxy=$http_proxy"
	fi

	if [ -n "$https_proxy" ]; then
		DOCKER_ENV_OPT="$DOCKER_ENV_OPT -e https_proxy=$https_proxy"
	fi

	$DOCKER_EXE pull $DEBIAN_IMAGE
	$DOCKER_EXE run --name $CONT_NAME -dti $DEBIAN_IMAGE bash
}

teardown() {
	docker rm -f $CONT_NAME
}

function docker_exec() {
	$DOCKER_EXE exec $DOCKER_ENV_OPT $CONT_ENV $CONT_NAME $@
}

@test "fstest : Posix conformance test suite" {
	skip "Issue https://github.com/clearcontainers/runtime/issues/828"
	docker_exec apt-get -y update
	docker_exec apt-get -y install git bc libacl1-dev libacl1 acl gcc make perl-modules
	docker_exec git clone $FSTEST_URL $FSTEST_DIR
	docker_exec make -C $FSTEST_DIR
	docker_exec prove -r $FSTEST_DIR
}
