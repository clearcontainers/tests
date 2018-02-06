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
source "/etc/os-release"
source "${cidir}/lib.sh"
get_cc_versions

if grep -q "N" /sys/module/kvm_intel/parameters/nested; then
	echo "enable Nested Virtualization"
	sudo modprobe -r kvm_intel
	sudo modprobe kvm_intel nested=1
fi

echo "Update apt repositories"
sudo -E apt update

echo "Install chronic"
sudo -E apt install -y moreutils

echo "Install test dependencies"
chronic sudo -E apt install -y python

echo "Install clear containers dependencies"
chronic sudo -E apt install -y libtool automake autotools-dev autoconf bc alien libpixman-1-dev

echo "Install qemu-lite binary"
"${cidir}/install_qemu_lite.sh" "${qemu_lite_clear_release}" "${qemu_lite_sha}" "$ID"

echo "Install CRI-O dependencies for all Ubuntu versions"
chronic sudo -E apt install -y libglib2.0-dev libseccomp-dev libapparmor-dev libgpgme11-dev go-md2man

echo "Install bison binary"
chronic sudo -E apt install -y bison

echo "Install libudev-dev"
chronic sudo -E apt-get install -y libudev-dev

echo "Install Build Tools"
sudo -E apt install -y build-essential python pkg-config zlib1g-dev


echo -e "Install CRI-O dependencies available for Ubuntu $VERSION_ID"
sudo -E apt install -y libdevmapper-dev btrfs-tools util-linux

if [ "$VERSION_ID" == "16.04" ]; then
	echo "Install os-tree"
	sudo -E add-apt-repository ppa:alexlarsson/flatpak -y
	sudo -E apt update
fi

sudo -E apt install -y libostree-dev

if ! command -v docker > /dev/null; then
	"${cidir}/../cmd/container-manager/manage_ctr_mgr.sh" docker install
fi
