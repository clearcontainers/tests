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
    echo "Usage: $0 <CLEAR_RELEASE> <QEMU_LITE_VERSION> <DISTRO>"
    echo "       Install the QEMU_LITE_VERSION from clear CLEAR_RELEASE."
    exit 1
fi

clear_release="$1"
qemu_lite_version="$2"
distro="$3"
qemu_lite_bin="qemu-lite-bin-${qemu_lite_version}.x86_64.rpm"
qemu_lite_data="qemu-lite-data-${qemu_lite_version}.x86_64.rpm"

echo -e "Install qemu-lite ${qemu_lite_version}"

# download packages
curl -LO "https://download.clearlinux.org/releases/${clear_release}/clear/x86_64/os/Packages/${qemu_lite_bin}"
curl -LO "https://download.clearlinux.org/releases/${clear_release}/clear/x86_64/os/Packages/${qemu_lite_data}"

# install packages
if [ "$distro" == "fedora" ]; then
    sudo rpm -ihv "./${qemu_lite_bin}" --nodeps
    sudo rpm -ihv "./${qemu_lite_data}" --nodeps
elif [ "$distro" == "ubuntu" ];  then
    sudo alien -i "./${qemu_lite_bin}"
    sudo alien -i "./${qemu_lite_data}"
fi

# cleanup
rm -f "./${qemu_lite_bin}"
rm -f "./${qemu_lite_data}"
