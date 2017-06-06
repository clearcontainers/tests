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

echo "Install proxy service (/etc/init/cc-proxy.conf)"
sudo cp "${cidir}/upstart-services/cc-proxy.conf" /etc/init/

echo "Start proxy service"
sudo service cc-proxy start
