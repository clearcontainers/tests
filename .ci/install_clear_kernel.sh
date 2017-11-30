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

if [ "$#" -ne 3 ]; then
    echo "Usage: $0 CLEAR_RELEASE KERNEL_VERSION PATH"
    echo "       Install the clear kernel image KERNEL_VERSION from clear CLEAR_RELEASE in PATH."
    exit 1
fi

clear_kernel_release="$1"
clear_container_kernel="$2"
# Get the kernel version number only
# E.g v4.9.60-80.container -> 4.9.60-80
clear_container_kernel="${clear_container_kernel/v}"
clear_container_kernel="${clear_container_kernel/.c*}"
install_path="$3"
clear_install_path="/usr/share/clear-containers"
vmlinux_kernel=vmlinux-${clear_container_kernel}.container
vmlinuz_kernel=vmlinuz-${clear_container_kernel}.container
cc_vmlinux_kernel_link_name="vmlinux.container"
cc_vmlinuz_kernel_link_name="vmlinuz.container"

echo -e "Install clear containers kernel ${clear_container_kernel}"

if [ "${clear_kernel_release}" == "demos" ]; then
	curl -LO "https://download.clearlinux.org/demos/clear-containers/linux-container-${clear_container_kernel}.x86_64.rpm"
else
	curl -LO "https://download.clearlinux.org/releases/${clear_kernel_release}/clear/x86_64/os/Packages/linux-container-${clear_container_kernel}.x86_64.rpm"
fi
rpm2cpio linux-container-${clear_container_kernel}.x86_64.rpm | cpio -ivdm
sudo install -D --owner root --group root --mode 0700 .${clear_install_path}/${vmlinux_kernel} ${install_path}/${vmlinux_kernel}
sudo install -D --owner root --group root --mode 0700 .${clear_install_path}/${vmlinuz_kernel} ${install_path}/${vmlinuz_kernel}

echo -e "Create symbolic link ${install_path}/${cc_vmlinux_kernel_link_name}"
sudo ln -fs ${install_path}/${vmlinux_kernel} ${install_path}/${cc_vmlinux_kernel_link_name}

echo -e "Create symbolic link ${install_path}/${cc_vmlinuz_kernel_link_name}"
sudo ln -fs ${install_path}/${vmlinuz_kernel} ${install_path}/${cc_vmlinuz_kernel_link_name}

# cleanup
rm -f linux-container-${clear_container_kernel}.x86_64.rpm
# be careful here, we don't want to rm something silly, note the leading .
rm -r .${clear_install_path}
rmdir ./usr/share
rmdir ./usr
