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
#

set -e

function clone_and_build() {
	github_project=$1
	make_target=$2
	project_dir=${GOPATH}/src/${github_project}
	project_url=https://${github_project}.git

	mkdir -p ${project_dir}
	pushd ${project_dir}

	if [ ! -d ".git" ]; then
		echo "Retrieve repository ${github_project}"
		git clone ${project_url} .
	else
		echo "Repository ${github_project} already cloned"
	fi

	# fixme: once tool to parse and get branches from github is
	# completed, add it here to fetch branches under testing

	echo "Build ${github_project}"
	if [ ! -f Makefile ]; then
		echo "Run autogen.sh to generate Makefile"
		bash -f autogen.sh
	fi
	make ${make_target}

	popd
}

function clone_build_and_install() {
	clone_and_build $1 $2
	pushd project_dir=${GOPATH}/src/${1}
	echo "Install repository ${1}"
	sudo make install
	popd
}
