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
	pr_branch="PR_${pr_number}"

	# Create a separate branch for the PR. This is required to allow
	# checkcommits to be able to determine how the PR differs from
	# "master".
	git fetch origin "pull/${pr_number}/head:${pr_branch}"
	git checkout "${pr_branch}"
	git rebase "origin/${ghprbTargetBranch}"
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

# Hack to make fetchbranches tool work under Jenkins.
# This needs to be removed once https://github.com/clearcontainers/tests/issues/872
# gets properly fixed.
if [ ${ghprbPullId} ]; then
	export PULL_REQUEST_NUMBER="${ghprbPullId}"
	export SEMAPHORE=true
	export SEMAPHORE_REPO_SLUG="${cc_repo/github.com\//}"
fi

# Make sure runc is default runtime.
# This is needed in case a new image creation.
# See https://github.com/clearcontainers/osbuilder/issues/8
"${GOPATH}/src/${tests_repo}/cmd/container-manager/manage_ctr_mgr.sh" docker configure -r runc -f

# Call the repo-specific setup script.
#
# It is assumed this script will:
#
# - Call "${tests_repo}/.ci/setup.sh"
#
#   This will setup the distro environment (get, build and install all the
#   latest components).
#
# - Call checkcommits.
bash "${GOPATH}/src/${cc_repo}/.ci/setup.sh"

if [ -n "$pr_number" ]
then
	# Now that checkcommits has run, move the PR commits into the master
	# branch before running the tests. Having the commits in "master" is
	# required to ensure coveralls works.
	git checkout master
	git reset --hard "$pr_branch"
	git branch -D "$pr_branch"
fi

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
