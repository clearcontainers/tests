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
source /etc/os-release

if grep -q "N" /sys/module/kvm_intel/parameters/nested; then
	echo "enable Nested Virtualization"
	sudo modprobe -r kvm_intel
	sudo modprobe kvm_intel nested=1
fi

sudo -E dnf -y install dnf-plugins-core
sudo -E dnf config-manager --add-repo \
http://download.opensuse.org/repositories/home:/clearcontainers:/clear-containers-3/Fedora_$VERSION_ID/home:clearcontainers:clear-containers-3.repo

sudo -E dnf makecache

echo "Install clear containers dependencies"
sudo -E dnf -y groupinstall "Development tools"
sudo -E dnf -y install libtool automake autoconf bc

echo "Install qemu-lite binary"
sudo -E dnf -y install qemu-lite

echo "Install clear-containers image"
sudo -E dnf -y install clear-containers-image

echo "Install Clear Containers Kernel"
sudo -E dnf -y install linux-container

echo "Install CRI-O dependencies"
sudo -E dnf -y install btrfs-progs-devel device-mapper-devel \
	glib2-devel glibc-devel glibc-static gpgme-devel         \
	libassuan-devel libgpg-error-devel libseccomp-devel      \
	libselinux-devel ostree-devel pkgconfig

echo "Install bison binary"
sudo -E dnf -y install bison

if ! command -v docker > /dev/null; then
	echo "Install Docker"
	docker_url="https://download.docker.com/linux/fedora"
	sudo -E dnf config-manager --add-repo "${docker_url}/docker-ce.repo"
	sudo -E dnf makecache
	sudo -E dnf -y install docker-ce
fi
