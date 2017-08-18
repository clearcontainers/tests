#!/bin/bash
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

# This test will perform several execs to a running container
# This test is designed to stress the agent

set -e -x

# Environment variables
DOCKER_EXE="docker"
image="busybox"
containerName="test"
# Timeout is the duration of this test (seconds)
timeout=186400
start_time=$(date +%s)
end_time=$((start_time+timeout))

function setup {
	if [ ! -z $("$DOCKER_EXE" ps -aq) ]; then
		$DOCKER_EXE rm -f $($DOCKER_EXE ps -aq)
	fi
	$DOCKER_EXE run -td --name $containerName $image sh
}

function exec_loop {
	$DOCKER_EXE exec $containerName sh -c "echo 'hello world' > file"
	$DOCKER_EXE exec $containerName sh -c "rm -rf /file"
	$DOCKER_EXE exec $containerName sh -c "ls /etc/resolv.conf 2>/dev/null " | grep "/etc/resolv.conf"
	$DOCKER_EXE exec $containerName sh -c "touch /tmp/execWorks"
	$DOCKER_EXE exec $containerName sh -c "ls /tmp | grep execWorks"
	$DOCKER_EXE exec $containerName sh -c "rm -rf /tmp/execWorks"
	$DOCKER_EXE exec $containerName sh -c "ls /etc/foo" || echo "Fail expected"
	$DOCKER_EXE exec $containerName sh -c "cat /tmp/one" || echo "Fail expected"
	$DOCKER_EXE exec $containerName sh -c "exit 42" || echo "Fail expected"
}

function teardown {
	$DOCKER_EXE rm -f $containerName
}

echo "Starting stability test"
setup

echo "Running stability test"
while [[ $end_time > $(date +%s) ]]; do
	exec_loop
done

echo "Ending stability test"
teardown
