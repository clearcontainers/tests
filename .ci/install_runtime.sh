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

tests_ci_dir=${GOPATH}/src/github.com/clearcontainers/tests/.ci

source ${tests_ci_dir}/lib.sh

runtime_dir="${GOPATH}/src/github.com/clearcontainers/runtime"
runtime_config_path="/etc/clear-containers"
runtime_config_file="configuration.toml"

clone_build_and_install "github.com/clearcontainers/runtime"

echo -e "Install runtime ${runtime_config_file} to ${runtime_config_path}"
sudo mkdir -p ${runtime_config_path}
sed 's/^#\(\[runtime\]\|global_log_path =\)/\1/g' ${runtime_dir}/config/${runtime_config_file} | sudo tee ${runtime_config_path}/${runtime_config_file}

echo "Add runtime as a new/default Docker runtime. Docker version \"$(docker --version)\" could change according to Semaphore CI updates."
sudo mkdir -p /etc/default
cat <<EOF
 EOF | sudo tee /etc/default/docker
DOCKER_OPTS="-D --add-runtime cc30=/usr/local/bin/cc-runtime --default-runtime=cc30"
EOF
EOF

echo "Restart docker service"
sudo service docker stop
sudo service docker start
