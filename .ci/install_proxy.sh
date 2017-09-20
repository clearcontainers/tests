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
#

set -e

cidir=$(dirname "$0")

source "${cidir}/lib.sh"

clone_build_and_install "github.com/clearcontainers/proxy"
start_proxy_cmd="sudo systemctl start cc-proxy"
upstart_source_file="${cidir}/data/cc-proxy.conf"
upstart_dest_file="/etc/init/cc-proxy.conf"
systemd_extra_flags="-log debug"


# If we are running under the metrics CI system then we do not want the proxy
# to be dynmaically changing the KSM settings under us - we need control of them
# ourselves
if [[ $METRICS_CI ]]; then
	upstart_source_file="${cidir}/data/cc-proxy.conf.noksm"
	systemd_extra_flags="${systemd_extra_flags} -ksm initial"
fi

# Are we running upstart or systemd?
if [[ ! $(ps -p 1 | grep systemd) ]]; then
	echo "Install proxy service (/etc/init/cc-proxy.conf)"
	sudo cp "${upstart_source_file}" "${upstart_dest_file}"

	start_proxy_cmd="sudo service cc-proxy start"
else
	proxy_systemd_file=$(sudo systemctl show cc-proxy | fgrep FragmentPath | awk 'BEGIN{FS="="}{print $2}')
	sudo sed -i "s/\(^ExecStart.*$\)/\1 ${systemd_extra_flags}/" "${proxy_systemd_file}"
	sudo systemctl daemon-reload
fi

echo "Start proxy service"
eval $start_proxy_cmd
