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

source "$HOME/vm_info"
cidir=$(dirname $(readlink -f $0))
ssh_options="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o IdentitiesOnly=yes"
ssh_key="$HOME/.ciao-down/id_rsa"
runtime_config_file="/etc/clear-containers/configuration.toml"

echo "Execute Tests"
# Change the default POD memory to 1024 MB since the ciao-down
# machines are being launched with 2048 MB of memory
ssh $ssh_options -i "$ssh_key" "$USER@$vm_ip" -p "$vm_port" \
	"cd ${cidir}/.. && sudo sed -i 's/#default_mem.*/default_memory = 1024/' $runtime_config_file"
ssh $ssh_options -i "$ssh_key" "$USER@$vm_ip" -p "$vm_port" "cd ${cidir}/.. && sudo -E PATH=\$PATH make check"
