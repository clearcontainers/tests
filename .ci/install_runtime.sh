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

# The OBS packages install qemu-lite here
export QEMUBINDIR=/usr/bin

# The runtimes config file should live here
export SYSCONFDIR=/etc

# Artifacts (kernel + image) live below here
export SHAREDIR=/usr/share

# shim + proxy
export PKGLIBEXECDIR=/usr/libexec/clear-containers

# For the pause bundle
export LOCALSTATEDIR=/var

runtime_dir="${GOPATH}/src/github.com/clearcontainers/runtime"
runtime_config_path="${SYSCONFDIR}/clear-containers/configuration.toml"

# Note: This will also install the config file.
clone_build_and_install "github.com/clearcontainers/runtime"

# Check system supports running Clear Containers
cc-runtime cc-check

echo "Enabling global logging for runtime in file ${runtime_config_path}"
sudo sed -i -e 's/^#\(\[runtime\]\|global_log_path =\)/\1/g' "${runtime_config_path}"

echo "Add runtime as a new/default Docker runtime. Docker version \"$(docker --version)\" could change according to Semaphore CI updates."
sudo mkdir -p /etc/default
cat << EOF | sudo tee /etc/default/docker
DOCKER_OPTS="-D --add-runtime cc30=/usr/local/bin/cc-runtime --default-runtime=cc30"
EOF

echo "Restart docker service"
sudo service docker stop
sudo service docker start
