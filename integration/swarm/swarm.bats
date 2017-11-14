#!/usr/bin/env bats
# *-*- Mode: sh; sh-basic-offset: 8; indent-tabs-mode: nil -*-*
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
# Swarm testing : This will start swarm as well as it will create and
# run swarm replicas using Nginx

# Environment variables
DOCKER_EXE="docker"
# Image for swarm testing
nginx_image="gabyct/nginx"
# Name of service to test swarm
SERVICE_NAME="testswarm"
# Maximum number of replicas that will be launch (just a quick test)
number_of_replicas=4
# Saves the name of the replicas
declare -a REPLICAS_UP
# Saves the hostname of the replicas
declare -a REPLICAS
# Url to retrieve hostname
url="http://127.0.0.1:8080/hostname"
# Timeout in seconds to verify replicas are running
timeout=10
# Retry number for the curl
number_of_retries=5

setup() {
	$DOCKER_EXE swarm init
	nginx_command="hostname > /usr/share/nginx/html/hostname; nginx -g \"daemon off;\""
	$DOCKER_EXE service create \
		--name "${SERVICE_NAME}" --replicas $number_of_replicas \
		--publish 8080:80 "${nginx_image}" sh -c "$nginx_command"
	running_regex='Running\s+\d+\s(seconds|minutes)\s+ago'
	for i in $(seq "$timeout") ; do
		$DOCKER_EXE service ls --filter name="$SERVICE_NAME"
		replicas_running=$($DOCKER_EXE service ps "$SERVICE_NAME" | grep -P "${running_regex}"  | wc -l)
		if [ "$replicas_running" -ge "$number_of_replicas" ]; then
			break
		fi
		sleep 1
	done
}

@test "check_replicas_interfaces" {
	# here we are checking that each replica has two interfaces
	# and they should be always eth0 and eth1
	REPLICAS_UP=($($DOCKER_EXE ps -q))
	for i in ${REPLICAS_UP[@]}; do
		$DOCKER_EXE exec $i sh -c "ip route show | grep -E eth0 && ip route show | grep -E eth1" > /dev/null
	done
}

@test "check_service_ip_among_the_replicas" {
	skip "This is not working (https://github.com/clearcontainers/tests/issues/694)"
	service_name=$($DOCKER_EXE service ls --filter name="${SERVICE_NAME}" -q)
	ip_service=$($DOCKER_EXE service inspect $SERVICE_NAME \
		--format='{{range .Endpoint.VirtualIPs}}{{.Addr}}{{end}}' | cut -d'/' -f1)
	REPLICAS_UP=($($DOCKER_EXE ps -q))
	for i in ${REPLICAS_UP[@]}; do
		# here we are checking that all the
		# replicas have the service ip
		$DOCKER_EXE exec $i bash -c "ip a | grep $ip_service" > /dev/null
	done
}

@test "obtain hostname of the replicas" {
	skip "This is not working (https://github.com/clearcontainers/runtime/issues/771)"
	proxy="$http_proxy"
	unset http_proxy
	for i in $(seq 0 $((number_of_replicas-1))); do
		REPLICAS[$i]="$(curl --connect-timeout $timeout --retry $number_of_retries $url)"
	done
	non_empty_elements="$(echo ${REPLICAS[@]} | egrep -o "[[:space:]]+" | wc -l)"
	if [ "$non_empty_elements" == "$((number_of_replicas-1))" ]; then
		break
	fi
	export http_proxy="$proxy"
}

@test "check mtu values in different interfaces" {
	skip "This is not working (https://github.com/clearcontainers/tests/issues/714)"
	REPLICAS_UP=$($DOCKER_EXE ps -q --filter name="${SERVICE_NAME}")
	for i in ${REPLICAS_UP[@]}; do
		network_settings_file=$($DOCKER_EXE inspect $i | grep "SandboxKey" | cut -d ':' -f2 | cut -d '"' -f2)
		[ -f "$network_settings_file" ]
		ip_addresses=$(nsenter --net="$network_settings_file" ip a)
		mtu_value_eth0=$(echo "$ip_addresses" | grep -w "eth0" | grep "mtu" | cut -d ' ' -f5)
		mtu_value_tap0=$(echo "$ip_addresses" | grep -w "tap0" | grep "mtu" | cut -d ' ' -f5)
		[ "$mtu_value_eth0" = "$mtu_value_tap0" ]
		mtu_value_eth1=$(echo "$ip_addresses" | grep -w "eth1" | grep "mtu" | cut -d ' ' -f5)
		mtu_value_tap1=$(echo "$ip_addresses" | grep -w "tap1" | grep "mtu" | cut -d ' ' -f5)
		[ "$mtu_value_eth1" = "$mtu_value_tap1" ]
	done
}

teardown() {
	$DOCKER_EXE service remove "${SERVICE_NAME}"
	$DOCKER_EXE swarm leave --force
}
