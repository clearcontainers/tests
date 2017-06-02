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

cidir=$(dirname "$0")

source "${cidir}/lib.sh"

virtcontainers_project="github.com/containers/virtcontainers"
virtcontainers_dir="${GOPATH}/src/${virtcontainers_project}"
virtcontainers_pause_bin=pause
virtcontainers_install_dir="/var/lib/clear-containers/runtime/bundles/pause_bundle/bin"

clone_and_build ${virtcontainers_project} ${virtcontainers_pause_bin}

echo "Install ${virtcontainers_pause_bin} binary"
sudo mkdir -p ${virtcontainers_install_dir}
sudo install --owner root --group root --mode 0755 ${virtcontainers_dir}/pause/${virtcontainers_pause_bin} ${virtcontainers_install_dir}
