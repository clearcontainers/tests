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

cidir=$(dirname "$0")

source "${cidir}/../test-versions.txt"

echo "Get CRI-O sources"
go get -d github.com/kubernetes-incubator/cri-o || true
pushd $GOPATH/src/github.com/kubernetes-incubator/cri-o
git fetch
git checkout "${crio_version}"

echo "Installing CRI-O"
make install.tools
make
sudo -E PATH=$PATH sh -c "make install"
sudo -E PATH=$PATH sh -c "make install.config"

containers_config_path="/etc/containers"
echo "Copy containers policy from CRI-O repo to $containers_config_path"
sudo mkdir -p "$containers_config_path"
sudo cp test/policy.json "$containers_config_path"

echo "Setup cc-runtime as the runtime to use"
sudo sed -i.bak 's/\/usr\/bin\/runc/\/usr\/local\/bin\/cc-runtime/g' /etc/crio/crio.conf

popd

service_path=""
crio_service_file=""
start_crio_cmd=""

if [[ $(ps -p 1 | grep systemd) ]]; then
	service_path="/etc/systemd/system"
	crio_service_file="${cidir}/data/crio.service"
	start_crio_cmd="sudo systemctl start crio"
else
	service_path="/etc/init"
	crio_service_file="${cidir}/data/crio.conf"
	start_crio_cmd="sudo service crio start"
fi

echo "Install crio service (${crio_service_file})"
sudo cp "${crio_service_file}" "${service_path}"

if [[ $(ps -p 1 | grep systemd) ]]; then
	echo "Reload systemd services"
	sudo systemctl daemon-reload
fi

echo "Start crio service"
eval $start_crio_cmd
