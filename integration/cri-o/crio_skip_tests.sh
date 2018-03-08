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

# Currently these are the CRI-O tests that are not working

declare -a skipCRIOTests=(
'test "ctr hostname env"'
'test "ctr execsync failure"'
'test "ctr execsync exit code"'
'test "ctr execsync std{out,err}"'
'test "ctr stop idempotent"'
'test "ctr caps drop"'
'test "run ctr with image with Config.Volumes"'
'test "ctr oom"'
'test "ctr create with non-existent command"'
'test "ctr create with non-existent command \[tty\]"'
'test "ctr update resources"'
'test "ctr correctly setup working directory"'
'test "ctr execsync conflicting with conmon env"'
'test "ctr resources"'
'test "ctr \/etc\/resolv.conf rw\/ro mode"'
);
