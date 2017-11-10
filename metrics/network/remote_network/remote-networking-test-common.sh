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
#

# This file contains functions that are shared among the networking
# tests that are using iperf

SCRIPT_PATH=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_PATH}/../../lib/common.bash"

# Argument of the test to run
argument="$1"
# Name of the interface were swarm will run
interface_name="$3"
# Name of the user (ssh)
ssh_user="$5"
# Ip address (ssh)
ssh_address="$7"
# Image for network testing
network_image="gabyct/network"
# Number of replicas that will be launch in each host
number_of_replicas=1
# Timeout in seconds to verify replicas are running
timeout=10
# Name of the first service
first_service="testswarm1"
# Name of the second service
second_service="testswarm2"
# Port where the first service will run
port_first_service="8080:80"
# Port where the second service will run
port_second_service="8081:80"

# This function will start swarm as well as it will label
# the nodes and create the replicas
function setup_swarm {
	token=$($DOCKER_EXE swarm init --advertise-addr "$interface_name")
	token_name=$(echo "$token" | grep "token" | head -1 | cut -d '\' -f1)
	ip_name=$(echo "$token" | grep ":" | tail -1)
	ssh "$ssh_user"@"$ssh_address" "$DOCKER_EXE swarm join $token_name $ip_name"
	first_node=$($DOCKER_EXE node ls -q | head -1)
	second_node=$($DOCKER_EXE node ls -q | tail -1)
	$DOCKER_EXE node update --label-add machine=machine1 "$first_node"
	$DOCKER_EXE node update --label-add machine=machine2 "$second_node"
	$DOCKER_EXE service create \
		--name "$first_service" --replicas "$number_of_replicas" \
		--constraint 'node.labels.machine == machine1' \
		--publish "$port_first_service" "$network_image" sh
	$DOCKER_EXE service create \
		--name "second_service" --replicas "$number_of_replicas" \
		--constraint 'node.labels.machine == machine2' \
		--publish "$port_second_service" "$network_image" sh
}

# This function will verify that the replica on the host client is running
function client_replica_status {
	for i in $(seq "$timeout"); do
		client_status=$($DOCKER_EXE ps -q --filter=status=running | wc -l)
		if [ "$client_status" -ge "$number_of_replicas" ]; then
			break
		fi
		sleep 1
	done
}

# This function will verify that the replica on the host server is running
function server_replica_status {
	for i in $(seq "$timeout"); do
		status=$(ssh "$ssh_user"@"$ssh_address" 'DOCKER_EXE=docker; \
		$DOCKER_EXE ps -q --filter=status=running | wc -l')
		if [ "$status" -ge "$number_of_replicas" ]; then
			break
		fi
		sleep 1
	done
}

# This function will verify the ip address of the server
function check_server_address {
	ssh "$ssh_user"@"$ssh_address" 'DOCKER_EXE=docker; \
			network_name=$($DOCKER_EXE network ls --filter driver=overlay -q); \
			$DOCKER_EXE network inspect "$network_name" --format "{{ range .Containers}} \
			{{ println .IPv4Address}}{{end}}" | head -n -2 | cut -d'/' -f1'
}

# This function will start an iperf3 server
function start_server {
	ssh "$ssh_user"@"$ssh_address" 'DOCKER_EXE=docker; \
			server_id=$($DOCKER_EXE ps -q); \
			server_command="mount -t ramfs -o size=20M ramfs /tmp && iperf3 -s"; \
			$DOCKER_EXE exec -d "$server_id" sh -c "$server_command"'
}

# This function will start an iperf3 client
function start_client {
	client_id="$1"
	client_command="$2"
	$DOCKER_EXE exec "$client_id" sh -c "$client_command"
}

# This function will remove swarm on both client and server hosts
function clean_environment {
	$DOCKER_EXE swarm leave --force
	ssh "$ssh_user"@"$ssh_address" "$DOCKER_EXE swarm leave --force"
}
