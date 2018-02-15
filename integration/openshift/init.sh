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

SCRIPT_PATH=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_PATH}/openshiftrc"

echo "Disable SELinux"
echo "There is an issue when runnig CRI-O workloads with SELinux enabled
For more information, please take a look at:
https://github.com/kubernetes-incubator/cri-o/issues/528"
sudo setenforce 0

echo "Create configuration files"
openshift start --write-config="$openshift_config_path"

cp "$node_config" "$node_crio_config"

cat << EOF >> "$node_crio_config"
kubeletArguments:
  node-labels:
  - region=infra
  image-service-endpoint:
  - "unix:///var/run/crio/crio.sock"
  container-runtime-endpoint:
  - "unix:///var/run/crio/crio.sock"
  container-runtime:
  - "remote"
  runtime-request-timeout:
  - "15m"
  cgroup-driver:
  - "cgroupfs"
EOF

echo "Start Master"
sudo -E openshift start master --config "$master_config" &> master.log &

echo "Start Node"
sudo -E openshift start node --config "$node_crio_config" &> node.log &
