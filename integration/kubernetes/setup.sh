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

script_path=$(dirname "$(readlink -f "$0")")
cidir="${script_path}/../../.ci"
source "${cidir}/lib.sh"
get_cc_versions

echo "Install Kubernetes"
sudo bash -c "cat <<EOF > /etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial-unstable main
EOF"
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
sudo -E apt update
sudo -E apt install -y docker.io kubelet="$kubernetes_version" kubeadm="$kubernetes_version" kubectl="$kubernetes_version"
sudo -E apt-mark hold kubelet kubeadm kubectl

echo "Install Clear Containers, including dependencies"
pushd "${cidir}"
./setup.sh
popd

echo "Modify kubelet systemd configuration to use CRI-O"
k8s_systemd_file="/etc/systemd/system/kubelet.service.d/10-kubeadm.conf"
sudo sed -i '/KUBELET_AUTHZ_ARGS/a Environment="KUBELET_EXTRA_ARGS=--container-runtime=remote --container-runtime-endpoint=/var/run/crio.sock --runtime-request-timeout=30m"' "$k8s_systemd_file"
sudo systemctl daemon-reload
