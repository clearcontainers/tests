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
script_name="${0##*/}"
script_dir="$(dirname $(realpath -s "$0"))"
release_tool="${script_dir}/release-tool"
owner=${OWNER:-clearcontainers}

function usage() {
cat << EOT
Usage: ${script_name} <repo>

Enviroment Variables:

TOKEN: Export GITHUB_TOKEN variable with a valid token and repository permissions
       See: https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/
EOT
exit
}

go build -o  "${release_tool}"

repo=$1
if [[ -z "$repo" ]]
then
	usage
fi

package="github.com/clearcontainers/${repo}"
commit="master"

go get -d "${package}" || true

pushd "${GOPATH}/src/${package}"
	remote=$(git remote -v | grep push | grep "${owner}/${repo}" | awk '{print $1}')
	git fetch --tags "${remote}"
	git fetch  "${remote}"
	git checkout master
	git pull "${remote}" master
	git checkout "${commit}"

	next_version="$(cat ./VERSION)"
	echo "Creating new version: ${next_version}"
	echo "Owner: ${owner}"

	if ! git rev-parse "${next_version}^{tag}"; then
		echo "Creating new tag"
		echo "Commit to tag:"
		git log -1 --oneline
		git tag -s -a -m "${next_version}" "${next_version}"
	else
		echo "Tag alrady exist"
	fi
	git push "${remote}" "${next_version}"
popd

${release_tool} --owner "${owner}" release --version "${next_version}" "${repo}"
