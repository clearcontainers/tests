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
# This test measures the request per second from the interconnection
# between a server container and the host using ab tool.
# container-server <----> host

set -e

SCRIPT_PATH=$(dirname "$(readlink -f "$0")")
source "${SCRIPT_PATH}/../lib/common.bash"
TEST_NAME="network nginx ab benchmark"

# Ports where it will run
port="80:80"
# Image name
image="nginx"
# Url
url="localhost:80"
# Number of requests to perform
# (large number to reduce standard deviation)
requests=100000
# Number of multiple requests to make
# (large number to reduce standard deviation)
concurrency=100

function nginx_ab_networking() {
	extra_args=" -p $port"
	total_requests="tmp.log"

	# Initialize/clean environment
	init_env
	check_images "$image"

	# Verify apache benchmark
	cmds=("ab")
	check_cmds "${cmds[@]}"

	# Launch nginx container
	$DOCKER_EXE run -d -p $port $image
	sleep_secs=2
	echo >&2 "WARNING: sleeping for $sleep_secs seconds to let the container start correctly"
	sleep "$sleep_secs"
	result="$(ab -n ${requests} -c ${concurrency} http://${url}/)"
	rps="$(echo "$result" | grep "Requests" | awk '{print $4}')"

	echo "Requests per second: $rps"
	save_results "$TEST_NAME" \
		"requests=${requests} concurrency=${concurrency}" \
		"$rps" "requests/s"

	clean_env
	echo "Finish"
}

nginx_ab_networking
