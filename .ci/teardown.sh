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

log_copy_dest="$1"

runtime_log_location="/var/lib/clear-containers/runtime/runtime.log"
runtime_log_filename="cc-runtime.log"
runtime_log_path="${log_copy_dest}/${runtime_log_filename}"

proxy_log_filename="cc-proxy.log"
proxy_log_path="${log_copy_dest}/${proxy_log_filename}"

shim_log_filename="cc-shim.log"
shim_log_path="${log_copy_dest}/${shim_log_filename}"

crio_log_filename="crio.log"
crio_log_path="${log_copy_dest}/${crio_log_filename}"

upstart_logs_path="/var/log/upstart"
upstart_proxy_path="${upstart_logs_path}/${proxy_log_filename}"
upstart_crio_path="${upstart_logs_path}/${crio_log_filename}"

# Copy log files if a destination path is provided, otherwise simply
# display them.
if [ ${log_copy_dest} ]; then
	sudo cp "${runtime_log_location}" "${runtime_log_path}"

	if [[ -n $(ps -p 1 | grep systemd) ]]; then
		sudo journalctl --no-pager -u cc-proxy > "${proxy_log_path}"
		sudo journalctl --no-pager -t cc-shim > "${shim_log_path}"
		sudo journalctl --no-pager -u crio > "${crio_log_path}"
	else
		sudo cp "${upstart_proxy_path}" > "${proxy_log_path}"
		sudo cp "${upstart_crio_path}" > "${crio_log_path}"
	fi
else
	echo "Clear Containers Runtime Log:"
	sudo cat "${runtime_log_location}"

	if [[ -n $(ps -p 1 | grep systemd) ]]; then
		echo "Clear Containers Proxy Log:"
		sudo journalctl --no-pager -u cc-proxy
		echo "Clear Containers Shim Log:"
		sudo journalctl --no-pager -t cc-shim
		echo "CRI-O Log:"
		sudo journalctl --no-pager -u crio
	else
		echo "Clear Containers Proxy Log:"
		sudo cat "${upstart_proxy_path}"
		echo "CRI-O Log:"
		sudo cat "${upstart_crio_path}"
	fi
fi
