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

echo "Install qemu Q35 binary"
sudo -E dnf -y install libcap-ng-devel pixman-devel libcap-devel libattr-devel python zlib-devel
git clone --branch qemu-lite-v2.9.0 https://github.com/clearcontainers/qemu.git --depth 1
qemu_dir="qemu"
pushd ${qemu_dir}
git checkout qemu-lite-v2.9.0
./configure --disable-tools --disable-libssh2 --disable-tcmalloc --disable-glusterfs    \
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
sudo -E mv "$(which qemu-system-x86_64)" /usr/bin/qemu-q35-system-x86_64
popd
rm -rf ${qemu_dir}

echo "Install bison binary"
sudo -E dnf -y install bison

if ! command -v docker > /dev/null; then
	echo "Install Docker"
	docker_url="https://download.docker.com/linux/fedora"
	sudo -E dnf config-manager --add-repo "${docker_url}/docker-ce.repo"
	sudo -E dnf makecache
	sudo -E dnf -y install docker-ce
fi
