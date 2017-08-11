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

if grep -q "N" /sys/module/kvm_intel/parameters/nested; then
	echo "enable Nested Virtualization"
	sudo modprobe -r kvm_intel
	sudo modprobe kvm_intel nested=1
fi

echo "Add clear containers sources to apt list"
sudo sh -c "echo 'deb http://download.opensuse.org/repositories/home:/clearcontainers:/clear-containers-3/xUbuntu_16.04/ /' >> /etc/apt/sources.list.d/clear-containers.list"
curl -fsSL http://download.opensuse.org/repositories/home:/clearcontainers:/clear-containers-3/xUbuntu_16.04/Release.key | sudo -E apt-key add -

echo "Update apt repositories"
sudo -E apt update

echo "Install chronic"
sudo -E apt install -y moreutils

echo "Install clear containers dependencies"
chronic sudo -E apt install -y libtool automake autotools-dev autoconf bc

echo "Install qemu-lite binary"
chronic sudo -E apt install -y --force-yes qemu-lite

echo "Install qemu-cc binary"
chronic sudo -E apt install -y --force-yes qemu-cc

echo "Install clear-containers image"
chronic sudo -E apt install -y --force-yes clear-containers-image

echo "Install CRI-O dependencies for all Ubuntu versions"
chronic sudo -E apt install -y libglib2.0-dev libseccomp-dev libapparmor-dev libgpgme11-dev

echo "Install bison binary"
chronic sudo -E apt install -y bison

echo "Install libudev-dev"
chronic sudo -E apt-get install -y libudev-dev

if [ "$VERSION_ID" == "14.04" ]; then
	echo "Install rpm2cpio"
	chronic sudo -E apt install -y rpm2cpio

	bug_url="https://github.com/clearcontainers/runtime/issues/91"
	cc_kernel_path="/usr/share/clear-containers"
	echo -e "\nWARNING:"
	echo "WARNING: Using backlevel kernel version ${kernel_version} due to bug ${bug_url}"
	echo -e "WARNING:\n"
	"${cidir}/install_clear_kernel.sh" "demos" ${kernel_version} "${cc_kernel_path}"

	echo "Build and Install libdevmapper"
	devmapper_version="2.02.172"
	curl -LOk ftp://sources.redhat.com/pub/lvm2/releases/LVM2.${devmapper_version}.tgz
	tar -xf LVM2.${devmapper_version}.tgz
	pushd LVM2.${devmapper_version}/
	./configure
	make -j$(nproc) libdm
	sudo -E PATH=$PATH sh -c "make libdm.install"
	popd
	rm -rf LVM2.${devmapper_version}/ LVM2.${devmapper_version}.tgz

	echo "Build Install btrfs-tools"
	sudo -E apt install -y asciidoc xmlto --no-install-recommends
	sudo -E apt install -y uuid-dev libattr1-dev libacl1-dev e2fslibs-dev libblkid-dev liblzo2-dev
	git clone http://git.kernel.org/pub/scm/linux/kernel/git/kdave/btrfs-progs.git
	pushd btrfs-progs
	./autogen.sh
	./configure
	make -j$(nproc) btrfs
	sudo -E PATH=$PATH sh -c "make install btrfs"
	popd

	echo "Build and Install nsenter"
	nsenter_version="2.30"
	chronic sudo -E apt install -y autopoint
	curl -LOk https://www.kernel.org/pub/linux/utils/util-linux/v${nsenter_version}/util-linux-${nsenter_version}.tar.xz
	tar -xf util-linux-${nsenter_version}.tar.xz
	pushd util-linux-${nsenter_version}/
	./autogen.sh
	./configure --without-python --disable-all-programs --enable-nsenter
	make nsenter
	sudo cp nsenter /usr/bin/
	popd
	rm -rf util-linux-${nsenter_version}/ util-linux-${nsenter_version}.tar.xz

	echo "Build and Install ostree"
	ostree_dir="ostree"
	chronic sudo -E apt install -y liblzma-dev e2p-dev libfuse-dev gtk-doc-tools libarchive-dev
	git clone https://github.com/ostreedev/ostree.git
	pushd ${ostree_dir}
	env NOCONFIGURE=1 ./autogen.sh
	./configure --prefix=/usr
	make -j4
	sudo -E PATH=$PATH sh -c "make install"
	popd
	rm -rf ${ostree_dir}

elif [ "$VERSION_ID" == "16.04" ]; then
	echo "Install Build Tools"
	sudo -E apt install -y build-essential python pkg-config zlib1g-dev

	echo "Install Clear Containers Kernel"
	sudo -E apt install -y linux-container

	echo "Install CRI-O dependencies available for Ubuntu 16.04"
	sudo -E apt install -y libdevmapper-dev btrfs-tools util-linux

	echo "Install os-tree"
	sudo -E add-apt-repository ppa:alexlarsson/flatpak -y
	sudo -E apt update
	sudo -E apt install -y libostree-dev

	echo "Install Docker"
	docker_url="https://download.docker.com/linux/ubuntu"
	sudo -E apt install -y apt-transport-https ca-certificates
	sudo -E add-apt-repository "deb [arch=amd64] ${docker_url} $(lsb_release -cs) stable"
	curl -fsSL "${docker_url}/gpg" | sudo -E apt-key add -
	sudo -E apt update
	sudo -E apt install -y docker-ce
fi
