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
source "$cidir/../test-versions.txt"
source "/etc/os-release"
cc_kernel_path="/usr/share/clear-containers"

if grep -q "N" /sys/module/kvm_intel/parameters/nested; then
	echo "enable Nested Virtualization"
	sudo modprobe -r kvm_intel
	sudo modprobe kvm_intel nested=1
fi

echo "Update apt repositories"
sudo -E apt update

echo "Install chronic"
sudo -E apt install -y moreutils

echo "Install clear containers dependencies"
chronic sudo -E apt install -y libtool automake autotools-dev autoconf bc alien libpixman-1-dev

echo "Install qemu-cc binary"
sudo sh -c "echo 'deb http://download.opensuse.org/repositories/home:/clearcontainers:/clear-containers-3-staging/xUbuntu_$(lsb_release -rs)/ /' >> /etc/apt/sources.list.d/clear-containers.list"
wget -qO - http://download.opensuse.org/repositories/home:/clearcontainers:/clear-containers-3-staging/xUbuntu_$(lsb_release -rs)/Release.key | sudo apt-key add -
sudo -E apt-get update
sudo -E apt-get -y install qemu-cc

echo "Install clear-containers image"
"${cidir}/install_clear_image.sh" "$image_version" "${cc_kernel_path}"

echo "Install CRI-O dependencies for all Ubuntu versions"
chronic sudo -E apt install -y libglib2.0-dev libseccomp-dev libapparmor-dev libgpgme11-dev

echo "Install bison binary"
chronic sudo -E apt install -y bison

echo "Install libudev-dev"
chronic sudo -E apt-get install -y libudev-dev


echo "Install Build Tools"
sudo -E apt install -y build-essential python pkg-config zlib1g-dev

echo "Install Clear Containers Kernel"
"${cidir}/install_clear_kernel.sh" "${kernel_clear_release}" "${kernel_version}" "${cc_kernel_path}"

echo -e "Install CRI-O dependencies available for Ubuntu $VERSION_ID"
sudo -E apt install -y libdevmapper-dev btrfs-tools util-linux

if [ "$VERSION_ID" == "16.04" ]; then
	echo "Install os-tree"
	sudo -E add-apt-repository ppa:alexlarsson/flatpak -y
	sudo -E apt update
fi

sudo -E apt install -y libostree-dev

if ! command -v docker > /dev/null; then
	echo "Install Docker"
	docker_url="https://download.docker.com/linux/ubuntu"
	sudo -E apt install -y apt-transport-https ca-certificates
	sudo -E add-apt-repository "deb [arch=amd64] ${docker_url} $(lsb_release -cs) stable"
	curl -fsSL "${docker_url}/gpg" | sudo -E apt-key add -
	sudo -E apt update
	sudo -E apt install -y docker-ce
fi
