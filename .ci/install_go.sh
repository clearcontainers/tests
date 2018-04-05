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

set -o errexit
set -o nounset
set -o pipefail

tmp_dir=$(mktemp -d -t install-go-tmp.XXXXXXXXXX)
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script_name="$(basename "${BASH_SOURCE[0]}")"
USE_VERSIONS_FILE=""
PROJECT="Clear Containers"

finish() {
	rm -rf "$tmp_dir"
}

die() {
	echo >&2 -e "\e[1mERROR\e[0m: $*"
	exit 1
}

info() {
	echo -e "\e[1mINFO\e[0m: $*"
}

usage(){
	exit_code="$1"
	cat <<EOT
Usage:

${script_name} [options] <args>

Args:
<go-version> : Install a specific go version.

Example:
${script_name} 1.10


Options
-p : Install go defined in ${PROJECT} versions file.
-h : Show this help

EOT
exit "$exit_code"
}


trap finish EXIT

pushd "${tmp_dir}"

while getopts hp opt
do
	case $opt in
		h)	usage 0 ;;
		p)	USE_VERSIONS_FILE="true"
	esac
done


go_version="${1:-""}"
if [ -z "$go_version" ];then
	usage 0
elif [ -n "${USE_VERSIONS_FILE}" ] ;then
	source "${script_dir}/lib.sh"
	get_cc_versions
fi



info "Download go version ${go_version}"
curl -OL https://storage.googleapis.com/golang/go${go_version}.linux-amd64.tar.gz
info "Remove old go installation"
sudo rm -r /usr/local/go/
info "Install go"
sudo tar -C /usr/local -xzf go${go_version}.linux-amd64.tar.gz
popd


