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

repo_owner="clearcontainers"
repo_name="linux"
cc_linux_releases_url="https://github.com/${repo_owner}/${repo_name}/releases"
#fake repository dir to query kernel version from remote
fake_repo_dir=$(mktemp -t -d cc-kernel.XXXX)

function cleanup {
	rm  -rf "${fake_repo_dir}"
}

trap cleanup EXIT


function usage() {
	cat << EOT
Usage: $0 <version>
Install the containers clear kernel image <version> from clearcontainers/linux.

version: Use 'latest' to pull latest kernel or a version from ${cc_linux_releases_url}
EOT

	exit 1
}

#Get latest version by checking remote tags
#We dont ask to github api directly because force a user to provide a GITHUB token
function get_latest_version {
	pushd ${fake_repo_dir} >> /dev/null
	git init -q
	git remote add origin  https://github.com/clearcontainers/linux.git

	cc_release=$(git ls-remote --tags 2>/dev/null \
		        | grep -oP '\-\d+\.container'  \
			        | grep -oP '\d+' \
				        | sort -n | \
					        tail -1 )

	tag=$(git ls-remote --tags 2>/dev/null \
		        | grep -oP "v\d+\.\d+\.\d+\-${cc_release}.container" \
			        | tail -1)

	popd >> /dev/null
	echo "${tag}"
}

function download_kernel() {
	local version=$1
	[ -n "${version}" ] || die "version not provided"
	if [ "${version}" == "latest" ]; then
		version=$(get_latest_version)
	fi
	echo "version to install ${version}"
	local binaries_dir="${version}-binaries"
	local binaries_tarball="${binaries_dir}.tar.gz"
	local shasum_file="SHA512SUMS"
	curl -OL "${cc_linux_releases_url}/download/${version}/${binaries_tarball}"
	curl -OL "${cc_linux_releases_url}/download/${version}/${shasum_file}"
	sha512sum -c ${shasum_file}
	tar xf "${binaries_tarball}"
	pushd "${binaries_dir}"
	sudo make install
	popd
}

cc_kernel_version="$1"

[ -z "${cc_kernel_version}" ] && usage
download_kernel "${cc_kernel_version}"
