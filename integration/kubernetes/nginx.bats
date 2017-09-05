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

load "${BATS_TEST_DIRNAME}/lib.sh"

setup() {
	nginx_image="nginx"
	busybox_image="busybox"
	service_name="${nginx_image}-service"
	export KUBECONFIG=/etc/kubernetes/admin.conf
	master=$(hostname)
	sudo -E kubectl taint nodes "$master" node-role.kubernetes.io/master:NoSchedule-
	sudo -E crioctl image pull "$busybox_image"
	sudo -E crioctl image pull "$nginx_image"
}

@test "Verify nginx connectivity between pods" {
	wait_time=20
	sleep_time=3
	output_file=$(mktemp)
	echo $output_file
	cmd="sudo -E kubectl get pods | grep $service_name | grep Running"
	sudo -E kubectl run "$service_name" --image="$nginx_image" --replicas=2
	sudo -E kubectl expose deployment "$service_name" --port=80
	sudo -E kubectl get svc,pod
	# Wait for nginx service to come up
	waitForProcess "$wait_time" "$sleep_time" "$cmd"
	run bash -c "sudo -E kubectl run test-nginx --rm -ti --restart=Never \
		--image=$busybox_image -- wget --timeout=1 $service_name > $output_file"
	[ "$status" -eq 0 ]
	grep "index.html" "$output_file"
}

teardown() {
	rm "$output_file"
	sudo -E kubectl delete deployment "$service_name"
}
