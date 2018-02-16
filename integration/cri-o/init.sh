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

set -e

# CRI-O service needs to be stopped here since the bats being run as part
# of the CRI-O integration tests actually start/stop the crio binary directly.
# That's why we don't want the crio service to be running at the same time,
# otherwise we end up with two binaries running at the same time, and stopping
# the binary fails since the system automatically restart the service if it is
# killed (which is the way the bats stop the binary).
echo "Stop crio service"
sudo systemctl stop crio
