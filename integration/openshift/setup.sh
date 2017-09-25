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
source /etc/os-release
source "$SCRIPT_PATH/../../test-versions.txt"

if [ "$ID" != fedora ]; then
	echo "Currently this script only works for Fedora."
	exit 1
fi

sudo -E dnf -y update

echo "Install Dependencies for Openshift"
sudo -E dnf -y install bind-utils bsdtar container-selinux createrepo \
		file jq json-glib-devel krb5-devel mercurial libassuan-devel \
		libselinux-python NetworkManager rsync skopeo-containers tito

echo "Install Clear Containers, including dependencies"
pushd "${SCRIPT_PATH}/../../.ci"
./setup.sh
popd

echo "Set Overlay as storage driver for CRI-O"
crio_config_file="/etc/crio/crio.conf"
sudo sed -i 's/storage_driver = ""/storage_driver = "overlay2"/' "$crio_config_file"

echo "Install Skopeo"
skopeo_repo="github.com/projectatomic/skopeo"
go get -d "$skopeo_repo" || true
pushd "$GOPATH/src/$skopeo_repo"
make binary-local
sudo -E make install-binary
popd

echo "Install Openshift"
openshift_repo="github.com/openshift/origin"
go get -d "$openshift_repo" || true
pushd "$GOPATH/src/$openshift_repo"
git checkout "$origin_version"
export OS_OUTPUT_GOPATH=1
make
sudo cp _output/local/bin/linux/amd64/{openshift,oc,oadm} /usr/bin
popd
echo "Openshift + CC Setup finished successfully"
