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

# Setup workflow:
# 1. setup environment (install qemu, kernel and image)
# 2. Clone repos, fetch branches, build and install

set -e

cidir=$(dirname "$0")

# If this script detects it is running in the repo it is hosted by,
# perform setup for that repo (not repos that use this one).
bash -f ${cidir}/setup_tests.sh

echo "Set up environment"
bash -f ${cidir}/setup_env_ubuntu.sh

echo "Install shim"
bash -f ${cidir}/install_shim.sh

echo "Install virtcontainers"
bash -f ${cidir}/install_virtcontainers.sh

echo "Install proxy"
bash -f ${cidir}/install_proxy.sh

echo "Install runtime"
bash -f ${cidir}/install_runtime.sh

echo "Install CNI plugins"
bash -f ${cidir}/install_cni_plugins.sh

echo "Install CRI-O"
bash -f ${cidir}/install_crio.sh
