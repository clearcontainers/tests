
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

# This script is in charge of building the fetch branches tool
# at clearcontainers/tests repository and then running it, in order to
# fetch a particular branch.

set -e

cidir=$(dirname "$0")

github_repository="src/github.com/clearcontainers/tests/cmd/fetchbranches"
tool_dir="${GOPATH}/${github_repository}"

pushd ${tool_dir} 

# Building the fetch branches tool
go build .
# Running the fetch branches tool
./fetchbranches

popd
