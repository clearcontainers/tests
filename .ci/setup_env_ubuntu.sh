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

echo "Install clear-containers image"
chronic sudo -E apt install -y --force-yes clear-containers-image

echo "Install CRI-O dependencies for all Ubuntu versions"
chronic sudo -E apt install -y libglib2.0-dev libseccomp-dev libapparmor-dev libgpgme11-dev

echo "Install qemu Q35 binary"
chronic sudo -E apt install -y libcap-ng-dev libpixman-1-dev libcap-dev libattr1-dev
git clone --branch qemu-lite-v2.9.0 https://github.com/clearcontainers/qemu.git --depth 1
qemu_dir="qemu"
pushd ${qemu_dir}
git checkout qemu-lite-v2.9.0
./configure --disable-tools --disable-libssh2 --disable-tcmalloc --disable-glusterfs        \
	--disable-seccomp --disable-{bzip2,snappy,lzo} --disable-usb-redir --disable-libusb \
	--disable-libnfs --disable-tcg-interpreter --disable-debug-tcg --disable-libiscsi   \
	--disable-rbd --disable-spice --disable-attr --disable-cap-ng --disable-linux-aio   \
	--disable-brlapi --disable-vnc-{jpeg,png,sasl} --disable-rdma --disable-bluez       \
	--disable-fdt --disable-curl --disable-curses --disable-sdl --disable-gtk           \
	--disable-tpm --disable-vte --disable-vnc --disable-xen --disable-opengl            \
	--disable-slirp --enable-trace-backend=nop --enable-virtfs --enable-attr            \
	--enable-cap-ng --target-list=x86_64-softmmu
make -j$(nproc)
sudo -E PATH=$PATH sh -c "make install"
sudo -E mv $(which qemu-system-x86_64) /usr/bin/qemu-q35-system-x86_64
popd
rm -rf ${qemu_dir}

echo "Install bison binary"
chronic sudo -E apt install -y bison

echo "Install libudev-dev"
chronic sudo -E apt-get install -y libudev-dev

if [ "$VERSION_ID" == "14.04" ]; then
	bug_url="https://github.com/clearcontainers/runtime/issues/91"
	test_kernel_path="${cidir}/kernel"
	cc_kernel_path="/usr/share/clear-containers"
	cc_kernel_link_name_vmlinux="vmlinux.container"
	cc_kernel_link_name_vmlinuz="vmlinuz.container"
	vmlinux="vmlinux-${kernel_version}.container"
	vmlinuz="vmlinuz-${kernel_version}.container"
	echo -e "\nWARNING:"
	echo "WARNING: Using backlevel kernel version ${kernel_version} due to bug ${bug_url}"
	echo -e "WARNING:\n"
	echo -e "Installing ${vmlinux}"
	sudo install -D --owner root --group root --mode 0700 "${test_kernel_path}/${vmlinux}" "${cc_kernel_path}/${vmlinux}"
	sudo ln -fs ${cc_kernel_path}/${vmlinux} ${cc_kernel_path}/${cc_kernel_link_name_vmlinux}
	echo -e "Installing ${vmlinuz}"
	sudo install -D --owner root --group root --mode 0700 "${test_kernel_path}/${vmlinuz}" "${cc_kernel_path}/${vmlinuz}"
	sudo ln -fs ${cc_kernel_path}/${vmlinuz} ${cc_kernel_path}/${cc_kernel_link_name_vmlinuz}

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
