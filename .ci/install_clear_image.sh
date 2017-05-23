
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

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 CLEAR_RELEASE PATH"
    echo "       Install the clear rootfs image from clear CLEAR_RELEASE in PATH."
    exit 1
fi

clear_release="$1"
install_path="$2"
image=clear-${clear_release}-containers.img
cc_img_link_name="clear-containers.img"
base_url="https://download.clearlinux.org/releases/${clear_release}/clear"

echo "Download clear containers image"
curl -LO "${base_url}/${image}.xz"

echo "Validate clear containers image checksum"
curl -LO "${base_url}/${image}.xz-SHA512SUMS"
sha512sum -c ${image}.xz-SHA512SUMS

echo "Extract clear containers image"
unxz ${image}.xz

sudo mkdir -p ${install_path}
echo "Install clear containers image"
sudo install -D --owner root --group root --mode 0755 ${image} ${install_path}/${image}

echo -e "Create symbolic link ${install_path}/${cc_img_link_name}"
sudo ln -fs ${install_path}/${image} ${install_path}/${cc_img_link_name}
