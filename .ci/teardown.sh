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

# This script will get any execution log that may be useful for
# debugging any issue related to Clear Containers.

runtime_log_file="/var/lib/clear-containers/runtime/runtime.log"

echo "Clear Containers Runtime Log:"
sudo cat "$runtime_log_file"

if [[ ! $(ps -p 1 | grep systemd) ]]; then
	upstart_logs_path="/var/log/upstart"
	echo "Clear Containers Proxy Log:"
	sudo cat "${upstart_logs_path}/cc-proxy.log"
	echo "CRI-O Log:"
	sudo cat "${upstart_logs_path}/crio.log"
else
	echo "Clear Containers Proxy Log:"
	sudo journalctl --no-pager -u cc-proxy
	echo "Clear Containers Shim Log:"
	sudo journalctl --no-pager -t cc-shim
	echo "CRI-O Log:"
	sudo journalctl --no-pager -u crio
fi
