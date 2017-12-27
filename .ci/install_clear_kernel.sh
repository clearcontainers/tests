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
function usage() {
    cat << EOT
Usage: $0 <version>
Install the containers clear kernel image <version> from clearcontainers/linux.

version: Use latest to pull latest kernel or a version from https://github.com/clearcontainers/linux/releases
EOT

exit 1
}

function download_kernel() {
	local version=$1
	local release_info_url="https://api.github.com/repos/clearcontainers/linux/releases/latest"
	[ -n "${version}" ] || die "version not provided"
	if [ "${version}" == "latest" ]; then
		release_json="$(curl -s ${release_info_url})"
	parse_py='
import json,sys
release=json.load(sys.stdin)
print release["tag_name"]
'
		version=$(echo "${release_json}" | python -c "$parse_py")
	fi
	echo "version to install ${version}"
	local binaries_dir="${version}-binaries"
	local binaries_tarball="${binaries_dir}.tar.gz"
	curl -OL "https://github.com/clearcontainers/linux/releases/download/${version}/${binaries_tarball}"
	tar xf "${binaries_tarball}"
	pushd "${binaries_dir}"
	sudo make install
	popd
}

cc_kernel_version="$1"

[ -z "${cc_kernel_version}" ] && usage
download_kernel "${cc_kernel_version}"
