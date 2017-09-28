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

load "${BATS_TEST_DIRNAME}/openshiftrc"
load "${BATS_TEST_DIRNAME}/../kubernetes/lib.sh"

setup() {
	pod_name="hello-openshift"
	image="openshift/${pod_name}"
	sudo -E /usr/local/bin/crioctl image pull "$image"
	cc_runtime_bin=$(command -v cc-runtime)
}

@test "Hello Openshift using CC" {
	# The below json file was taken from:
	# https://github.com/openshift/origin/tree/master/examples/hello-openshift
	# and modified to be an untrusted workload and then use Clear Containers.
	sudo -E oc create -f "${BATS_TEST_DIRNAME}/data/hello-pod-cc.json"
	wait_time=20
	sleep_time=3
	output_file=$(mktemp)
	cmd="sudo -E oc describe pod/${pod_name} | grep State | grep Running"
	# Wait for nginx service to come up
	waitForProcess "$wait_time" "$sleep_time" "$cmd"
	container_id=$(sudo -E oc describe pod/${pod_name} | grep "Container ID" | cut -d '/' -f3)
	# Verify that the running container is a Clear Container
	sudo -E "$cc_runtime_bin" list | grep "$container_id" | grep "running"
	# Verify connectivity
	container_ip=$(sudo -E oc get pod "${pod_name}" -o yaml | grep "podIP" | awk '{print $2}')
	container_port=$(sudo -E oc get pod "${pod_name}" -o yaml | grep "Port" | awk '{print $3}')
	curl "${container_ip}:${container_port}" &> "$output_file"
	grep "Hello OpenShift" "$output_file"
}

teardown() {
	rm "$output_file"
	sudo -E oc delete pod "$pod_name"
}
