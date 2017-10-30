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
cc_kernel_path="/usr/share/clear-containers"

if grep -q "N" /sys/module/kvm_intel/parameters/nested; then
	echo "enable Nested Virtualization"
	sudo modprobe -r kvm_intel
	sudo modprobe kvm_intel nested=1
fi

echo "Install chronic"
sudo -E dnf -y install moreutils

chronic sudo -E dnf -y install dnf-plugins-core
chronic sudo -E dnf makecache

echo "Install clear containers dependencies"
chronic sudo -E dnf -y groupinstall "Development tools"
chronic sudo -E dnf -y install libtool automake autoconf bc pixman numactl-libs

echo "Install qemu-lite binary"
"${cidir}/install_qemu_lite.sh" "${qemu_clear_release}" "${qemu_lite_sha}" "$ID"

echo "Install clear-containers image"
"${cidir}/install_clear_image.sh" "$image_version" "${cc_kernel_path}"

echo "Install Clear Containers Kernel"
"${cidir}/install_clear_kernel.sh" "${kernel_clear_release}" "${kernel_version}" "${cc_kernel_path}"

echo "Install CRI-O dependencies"
chronic sudo -E dnf -y install btrfs-progs-devel device-mapper-devel 	  \
	glib2-devel glibc-devel glibc-static gpgme-devel libassuan-devel  \
	libgpg-error-devel libseccomp-devel libselinux-devel ostree-devel \
	pkgconfig

echo "Install bison binary"
chronic sudo -E dnf -y install bison

if ! command -v docker > /dev/null; then
	echo "Install Docker"
	docker_url="https://download.docker.com/linux/fedora"
	chronic sudo -E dnf config-manager --add-repo "${docker_url}/docker-ce.repo"
	chronic sudo -E dnf makecache
	chronic sudo -E dnf -y install docker-ce
fi
