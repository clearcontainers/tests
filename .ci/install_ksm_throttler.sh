#!/bin/bash
#
# Copyright (c) 2018 Intel Corporation
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

clone_build_and_install "github.com/kata-containers/ksm-throttler"

# If we are running under the metrics CI system then we do not want the proxy
# to be dynmaically changing the KSM settings under us - we need control of them
# ourselves
if [[ ! $METRICS_CI ]]; then
	sudo systemctl daemon-reload
	sudo systemctl enable vc-throttler.service
	sudo systemctl start vc-throttler.service
fi

# Stop and disable cc-proxy service in case the service files
# are installed.
sudo systemctl daemon-reload
sudo systemctl disable cc-proxy || true
sudo systemctl stop cc-proxy || true
