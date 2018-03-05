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

QEMU_REPO="qemu"

git clone https://github.com/qemu/qemu

pushd $QEMU_REPO
git checkout stable-2.10

curl https://raw.githubusercontent.com/clearcontainers/packaging/master/qemu-lite/configure.patch | patch -p1

./configure --disable-static --disable-bluez --disable-brlapi --disable-bzip2 --disable-curl \
--disable-curses --disable-debug-tcg --disable-fdt --disable-glusterfs --disable-gtk \
--disable-libiscsi --disable-libnfs --disable-libssh2 --disable-libusb --disable-linux-aio \
--disable-lzo --disable-opengl --disable-qom-cast-debug --disable-rbd --disable-rdma --disable-sdl \
--disable-seccomp --disable-slirp --disable-snappy --disable-spice --disable-strip \
--disable-tcg-interpreter --disable-tcmalloc --disable-tools --disable-tpm --disable-usb-redir \
--disable-uuid --disable-vnc --disable-vnc-jpeg --disable-vnc-png --disable-vnc-sasl --disable-vte \
--disable-xen --enable-attr --enable-cap-ng --enable-kvm --enable-virtfs \
--target-list=x86_64-softmmu --extra-cflags="-fno-semantic-interposition -O3 -falign-functions=32" \
--datadir=/usr/share/qemu-lite --libdir=/usr/lib64/qemu-lite --libexecdir=/usr/libexec/qemu-lite \
--enable-vhost-net --disable-docs

make

sudo -E make install
popd
