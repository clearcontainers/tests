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

# Need the repo to know which tests to run.
cc_repo=$1

tests_repo="github.com/clearcontainers/tests"

# This script is intended to execute under Jenkins
# If we do not know where the Jenkins defined WORKSPACE area is
# then quit
if [ -z "${WORKSPACE}" ]
then
	echo "Jenkins WORKSPACE env var not set - exiting" >&2
	exit 1
fi

# Put our go area into the Jenkins job WORKSPACE tree
export GOPATH=${WORKSPACE}/go
mkdir -p ${GOPATH}

# Export all environment variables needed.
export GOROOT="/usr/local/go"
export PATH=${GOPATH}/bin:/usr/local/go/bin:/usr/sbin:/sbin:${PATH}

# We need to set CI in order to enable proper coverage tool operation
export CI=true

# Download and build goveralls binary in case we need to submit the code
# coverage.
if [ ${COVERALLS_REPO_TOKEN} ]
then
	go get github.com/mattn/goveralls
fi

# Get the repository and move to the correct commit
go get ${cc_repo} || true
pushd ${GOPATH}/src/${cc_repo}

pr_number=

[ "${ghprbPullId}" ] && [ "${ghprbTargetBranch}" ] && pr_number="${ghprbPullId}"

if [ -n "$pr_number" ]
then
	# For PRs we rebase the PR commits onto the defined target branch
	git fetch origin "pull/${ghprbPullId}/head" && git checkout master && git reset --hard FETCH_HEAD && git rebase origin/${ghprbTargetBranch}
else
	# Othewise we test the master branch
	git fetch origin && git checkout master && git reset --hard origin/master
fi

# All repos apart from the test repo run some setup/checks from their own
# .ci/setup.sh before invoking the test repo .ci/setup.sh. Thus, the test
# repo has its own pre-setup.sh script that needs running
if [ "${cc_repo}" == "${tests_repo}" ]
then
        .ci/setup_tests.sh
fi

# Set up the distro environment. Get, build and install all the latest
# components
.ci/setup.sh

# The metrics CI does not need to do the QA checks - it only runs once
# it knows the QA CI has passed already.
if [ -z "${METRICS_CI}" ]
then
	# Run the test suite
	.ci/run.sh
else
	echo "Under METRICS_CI - skipping test run"
fi

# Publish the code coverage if needed.
if [ ${COVERALLS_REPO_TOKEN} ]
then
	sudo -E PATH=${PATH} bash -c "${GOPATH}/bin/goveralls -repotoken=${COVERALLS_REPO_TOKEN} -coverprofile=profile.cov"
fi

popd
