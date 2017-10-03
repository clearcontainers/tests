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

setup() {
	$DOCKER_EXE swarm init
	nginx_command="hostname > /usr/share/nginx/html/hostname; nginx -g \"daemon off;\""
	$DOCKER_EXE service create \
		--name "${SERVICE_NAME}" --replicas $number_of_replicas \
		--publish 8080:80 "${nginx_image}" sh -c "$nginx_command"
	running_regex='Running\s+\d+\s(seconds|minutes)\s+ago'
	replicas_running=$(docker service ps "$service" | grep -P "${running_regex}"  | wc -l)
	if [ "$replicas_running" -ne "$number_of_replicas" ]; then
		# this is needed as replicas do not run inmediately
		sleep 1
	else
		break
	fi
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
	service_name=$($DOCKER_EXE service ls --filter name="${SERVICE_NAME}" -q)
	ip_service=$($DOCKER_EXE service inspect $service_name \
		--format='{{range .Endpoint.VirtualIPs}}{{.Addr}}{{end}}' | cut -d'/' -f1)
	REPLICAS_UP=($($DOCKER_EXE ps -q))
	for i in ${REPLICAS_UP[@]}; do
		# here we are checking that all the
		# replicas have the service ip
		$DOCKER_EXE exec $i bash -c "ip a | grep $ip_service" > /dev/null
	done
}

teardown() {
	$DOCKER_EXE service remove "${SERVICE_NAME}"
	$DOCKER_EXE swarm leave --force
}
