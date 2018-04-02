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


tmp_dir=$(mktemp -d -t tmp.XXXXXXXXXX)
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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


trap finish EXIT

source "${script_dir}/lib.sh"
get_cc_versions

#TODO (jcvenega) remove after https://github.com/clearcontainers/runtime/pull/1091 is merged
cri_containerd_version="v1.0.0-rc.0"

info "Get cri containerd sources"
repo="github.com/containerd/cri"
go get -d "$repo" || true
pushd "${GOPATH}/src/${repo}"
git fetch
info "Checkout to ${cri_containerd_version}"
git checkout "${cri_containerd_version}"
info "Installing cri-containerd"
make install.tools
make install.deps
make
sudo -E PATH=$PATH make install
