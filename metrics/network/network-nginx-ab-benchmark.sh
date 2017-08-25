#!/bin/bash

#  Copyright (C) 2017 Intel Corporation
#
#  This program is free software; you can redistribute it and/or
#  modify it under the terms of the GNU General Public License
#  as published by the Free Software Foundation; either version 2
#  of the License, or (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# Description:
#  Test (host<->docker) network performance using
#  an nginx container and running the Apache 
#  benchmarking tool in the host to calculate the 
#  requests per second

set -e

SCRIPT_PATH=$(dirname "$(readlink -f "$0")")

source "${SCRIPT_PATH}/../lib/common.bash"

# Ports where it will run
port=80:80
# Image name
image=nginx
# Url
url=localhost:80
# Number of requests to perform
# (large number to reduce standard deviation)
requests=100000
# Number of multiple requests to make
# (large number to reduce standard deviation)
concurrency=100

function setup {
	runtime_docker
	kill_processes_before_start
}

# This script will perform all the measurements using a local setup

# Test single host<->docker requests per second using nginx and ab

function nginx_ab_networking {
	cmds=("ab")
	check_cmds "${cmds[@]}"
	setup
	container_name="docker-nginx"
	total_requests=$(mktemp)

	$DOCKER_EXE run -d --name ${container_name} --runtime $RUNTIME -p ${port} ${image} > /dev/null
	sleep_secs=2
	echo >&2 "WARNING: sleeping for $sleep_secs seconds (see https://github.com/01org/cc-oci-runtime/issues/828)"
	sleep "$sleep_secs"
	ab -n ${requests} -c ${concurrency} http://${url}/ > "$total_requests"

	cp -p $total_requests result.test

	local result=$(grep "^Requests per second" $total_requests)
	[[ $result =~ :[[:blank:]]*([[:digit:]]+(\.[[:digit:]]*)?) ]] && rps=${BASH_REMATCH[1]}
	$DOCKER_EXE rm -f ${container_name} > /dev/null	
	rm -f "$total_requests"
}

nginx_ab_networking
echo "The total of requests per second is : $rps"
save_results "network nginx ab benchmark" \
	"requests=${requests} concurrency=${concurrency}" \
	"$rps" "requests/s"
