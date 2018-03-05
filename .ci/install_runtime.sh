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

# Modify the runtimes build-time defaults

# enable verbose build
export V=1

# tell the runtime build to use sane defaults
export CC_SYSTEM_BUILD="yes"

# The runtimes config file should live here
export SYSCONFDIR=/etc

# Artifacts (kernel + image) live below here
export SHAREDIR=/usr/share

runtime_config_path="${SYSCONFDIR}/clear-containers/configuration.toml"

PKGDEFAULTSDIR="${SHAREDIR}/defaults/clear-containers"
NEW_RUNTIME_CONFIG="${PKGDEFAULTSDIR}/configuration.toml"

# Note: This will also install the config file.
clone_build_and_install "github.com/clearcontainers/runtime"

# Check system supports running Clear Containers
cc-runtime cc-check

if [ -e "${NEW_RUNTIME_CONFIG}" ]; then
	# Remove the legacy config file
	sudo rm -f "${runtime_config_path}"

	# Use the new path
	runtime_config_path="${NEW_RUNTIME_CONFIG}"
fi

echo "Enabling global logging for runtime in file ${runtime_config_path}"
sudo sed -i -e 's/^#\(\[runtime\]\|global_log_path =\)/\1/g' "${runtime_config_path}"

echo "Enabling all debug options in file ${runtime_config_path}"
sudo sed -i -e 's/^#\(enable_debug\).*=.*$/\1 = true/g' "${runtime_config_path}"

echo "Change Qemu Path"
OLD_QEMU_PATH=/usr/bin/qemu-lite-system-x86_64
QEMU_PATH=$(which qemu-system-x86_64)
sudo sed -i "s|$OLD_QEMU_PATH|$QEMU_PATH|" "${runtime_config_path}"

echo "Add cc-runtime as a new/default Docker runtime."

"${cidir}/../cmd/container-manager/manage_ctr_mgr.sh" docker configure -r cc-runtime -f
