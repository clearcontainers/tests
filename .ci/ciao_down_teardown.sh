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
runtime_log_file="/var/lib/clear-containers/runtime/runtime.log"

echo "Execute Tests"
ssh $ssh_options -i "$ssh_key" "$USER@$vm_ip" -p "$vm_port" "sudo cat $runtime_log_file"
ssh $ssh_options -i "$ssh_key" "$USER@$vm_ip" -p "$vm_port" "sudo journalctl -u cc-proxy"
ssh $ssh_options -i "$ssh_key" "$USER@$vm_ip" -p "$vm_port" "sudo journalctl -u crio"
