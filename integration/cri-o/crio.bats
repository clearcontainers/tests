#!/usr/bin/env bats

# Copyright (c) 2017-2018 Intel Corporation
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

load helpers

function teardown() {
	cleanup_test
}

@test "ctr not found correct error message" {
	start_crio
	run crictl inspect "container_not_exist"
	echo "$output"
	[ "$status" -eq 1 ]

	stop_crio
}

@test "ctr termination reason Completed" {
	start_crio
	run crictl runs "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	pod_id="$output"
	run crictl create "$pod_id" "$TESTDATA"/container_config.json "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	ctr_id="$output"
	run crictl start "$ctr_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run sleep 5
	run crictl inspect --output yaml "$ctr_id"
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "reason: Completed" ]]

	cleanup_ctrs
	cleanup_pods
	stop_crio
}

@test "ctr termination reason Error" {
	start_crio
	run crictl runs "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	pod_id="$output"
	errorconfig=$(cat "$TESTDATA"/container_config.json | python -c 'import json,sys;obj=json.load(sys.stdin);obj["command"] = ["false"]; json.dump(obj, sys.stdout)')
	echo "$errorconfig" > "$TESTDIR"/container_config_error.json
	run crictl create "$pod_id" "$TESTDIR"/container_config_error.json "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	ctr_id="$output"
	run crictl start "$ctr_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run sleep 5
	run crictl inspect --output yaml "$ctr_id"
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "reason: Error" ]]

	cleanup_ctrs
	cleanup_pods
	stop_crio
}

@test "ctr remove" {
	start_crio
	run crictl runs "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	pod_id="$output"
	run crictl create "$pod_id" "$TESTDATA"/container_redis.json "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	ctr_id="$output"
	run crictl start "$ctr_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl rm "$ctr_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl stops "$pod_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl rms "$pod_id"
	echo "$output"
	[ "$status" -eq 0 ]
	cleanup_ctrs
	cleanup_pods
	stop_crio
}

@test "ctr lifecycle" {
	start_crio
	run crictl runs "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	pod_id="$output"
	run crictl sandboxes --quiet
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" == "$pod_id" ]]
	run crictl create "$pod_id" "$TESTDATA"/container_redis.json "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	ctr_id="$output"
	run crictl ps --quiet
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" == "$ctr_id" ]]
	run crictl inspect "$ctr_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl start "$ctr_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl inspect "$ctr_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl ps --quiet
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" == "$ctr_id" ]]
	run crictl stop "$ctr_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl inspect "$ctr_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl ps --quiet
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" == "$ctr_id" ]]
	run crictl rm "$ctr_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl ps --quiet
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl stops "$pod_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl sandboxes --quiet
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" == "$pod_id" ]]
	run crictl ps --quiet
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" == "" ]]
	run crictl rms "$pod_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl sandboxes --quiet
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" == "" ]]
	cleanup_ctrs
	cleanup_pods
	stop_crio
}

@test "ctr logging" {
	start_crio
	run crictl runs "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	pod_id="$output"

	# Create a new container.
	newconfig=$(mktemp --tmpdir crio-config.XXXXXX.json)
	cp "$TESTDATA"/container_config_logging.json "$newconfig"
	sed -i 's|"%shellcommand%"|"echo here is some output \&\& echo and some from stderr >\&2"|' "$newconfig"
	run crictl create "$pod_id" "$newconfig" "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	ctr_id="$output"
	run crictl start "$ctr_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl stop "$ctr_id"
	echo "$output"
	# Ignore errors on stop.
	run crictl inspect "$ctr_id"
	[ "$status" -eq 0 ]
	run crictl rm "$ctr_id"
	echo "$output"
	[ "$status" -eq 0 ]

	# Check that the output is what we expect.
	logpath="$DEFAULT_LOG_PATH/$pod_id/$ctr_id.log"
	[ -f "$logpath" ]
	echo "$logpath :: $(cat "$logpath")"
	grep -E "^[^\n]+ stdout F here is some output$" "$logpath"
	grep -E "^[^\n]+ stderr F and some from stderr$" "$logpath"

	run crictl stops "$pod_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl rms "$pod_id"
	echo "$output"
	[ "$status" -eq 0 ]

	cleanup_ctrs
	cleanup_pods
	stop_crio
}

@test "ctr logging [tty=true]" {
	start_crio
	run crictl runs "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	pod_id="$output"

	# Create a new container.
	newconfig=$(mktemp --tmpdir crio-config.XXXXXX.json)
	cp "$TESTDATA"/container_config_logging.json "$newconfig"
	sed -i 's|"%shellcommand%"|"echo here is some output"|' "$newconfig"
	sed -i 's|"tty": false,|"tty": true,|' "$newconfig"
	run crictl create "$pod_id" "$newconfig" "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	ctr_id="$output"
	run crictl start "$ctr_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl stop "$ctr_id"
	echo "$output"
	# Ignore errors on stop.
	run crictl inspect "$ctr_id"
	[ "$status" -eq 0 ]
	run crictl rm "$ctr_id"
	echo "$output"
	[ "$status" -eq 0 ]

	# Check that the output is what we expect.
	logpath="$DEFAULT_LOG_PATH/$pod_id/$ctr_id.log"
	[ -f "$logpath" ]
	echo "$logpath :: $(cat "$logpath")"
	grep --binary -P "^[^\n]+ stdout F here is some output\x0d$" "$logpath"

	run crictl stops "$pod_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl rms "$pod_id"
	echo "$output"
	[ "$status" -eq 0 ]

	cleanup_ctrs
	cleanup_pods
	stop_crio
}

@test "ctr list filtering" {
	# start 3 redis sandbox
	# pod1 ctr1 create & start
	# pod2 ctr2 create
	# pod3 ctr3 create & start & stop
	start_crio
	run crictl runs "$TESTDATA"/sandbox1_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	pod1_id="$output"
	run crictl create "$pod1_id" "$TESTDATA"/container_redis.json "$TESTDATA"/sandbox1_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	ctr1_id="$output"
	run crictl start "$ctr1_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl runs "$TESTDATA"/sandbox2_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	pod2_id="$output"
	run crictl create "$pod2_id" "$TESTDATA"/container_redis.json "$TESTDATA"/sandbox2_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	ctr2_id="$output"
	run crictl runs "$TESTDATA"/sandbox3_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	pod3_id="$output"
	run crictl create "$pod3_id" "$TESTDATA"/container_redis.json "$TESTDATA"/sandbox3_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	ctr3_id="$output"
	run crictl start "$ctr3_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl stop "$ctr3_id"
	echo "$output"
	[ "$status" -eq 0 ]

	run crictl ps --id "$ctr1_id" --quiet
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" == "$ctr1_id" ]]
	run crictl ps --id "${ctr1_id:0:4}" --quiet
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" == "$ctr1_id" ]]
	run crictl ps --id "$ctr2_id" --sandbox "$pod2_id" --quiet
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" == "$ctr2_id" ]]
	run crictl ps --id "$ctr2_id" --sandbox "$pod3_id" --quiet
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" == "" ]]
	run crictl ps --state created --quiet
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" == "$ctr2_id" ]]
	run crictl ps --state running --quiet
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" == "$ctr1_id" ]]
	run crictl ps --state stopped --quiet
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" == "$ctr3_id" ]]
	run crictl ps --sandbox "$pod1_id" --quiet
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" == "$ctr1_id" ]]
	run crictl ps --sandbox "$pod2_id" --quiet
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" == "$ctr2_id" ]]
	run crictl ps --sandbox "$pod3_id" --quiet
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" == "$ctr3_id" ]]
	run crictl stops "$pod1_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl rms "$pod1_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl stops "$pod2_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl rms "$pod2_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl stops "$pod3_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl rms "$pod3_id"
	echo "$output"
	[ "$status" -eq 0 ]
	cleanup_ctrs
	cleanup_pods
	stop_crio
}

@test "ctr list label filtering" {
	# start a pod with 3 containers
	# ctr1 with labels: group=test container=redis version=v1.0.0
	# ctr2 with labels: group=test container=redis version=v1.0.0
	# ctr3 with labels: group=test container=redis version=v1.1.0
	start_crio

	run crictl runs "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	pod_id="$output"

	ctrconfig=$(cat "$TESTDATA"/container_config.json | python -c 'import json,sys;obj=json.load(sys.stdin);obj["metadata"]["name"] = "ctr1";obj["labels"]["group"] = "test";obj["labels"]["name"] = "ctr1";obj["labels"]["version"] = "v1.0.0"; json.dump(obj, sys.stdout)')
	echo "$ctrconfig" > "$TESTDATA"/labeled_container_redis.json
	run crictl create "$pod_id" "$TESTDATA"/labeled_container_redis.json "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	ctr1_id="$output"

	ctrconfig=$(cat "$TESTDATA"/container_config.json | python -c 'import json,sys;obj=json.load(sys.stdin);obj["metadata"]["name"] = "ctr2";obj["labels"]["group"] = "test";obj["labels"]["name"] = "ctr2";obj["labels"]["version"] = "v1.0.0"; json.dump(obj, sys.stdout)')
	echo "$ctrconfig" > "$TESTDATA"/labeled_container_redis.json
	run crictl create "$pod_id" "$TESTDATA"/labeled_container_redis.json "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	ctr2_id="$output"

	ctrconfig=$(cat "$TESTDATA"/container_config.json | python -c 'import json,sys;obj=json.load(sys.stdin);obj["metadata"]["name"] = "ctr3";obj["labels"]["group"] = "test";obj["labels"]["name"] = "ctr3";obj["labels"]["version"] = "v1.1.0"; json.dump(obj, sys.stdout)')
	echo "$ctrconfig" > "$TESTDATA"/labeled_container_redis.json
	run crictl create "$pod_id" "$TESTDATA"/labeled_container_redis.json "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	ctr3_id="$output"

	run crictl ps --label "group=test" --label "name=ctr1" --label "version=v1.0.0" --quiet
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" == "$ctr1_id" ]]
	run crictl ps --label "group=production" --quiet
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" == "" ]]
	run crictl ps --label "group=test" --label "version=v1.0.0" --quiet
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" != "" ]]
	[[ "$output" =~ "$ctr1_id" ]]
	[[ "$output" =~ "$ctr2_id" ]]
	[[ "$output" != "$ctr3_id" ]]
	run crictl ps --label "group=test" --quiet
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" != "" ]]
	[[ "$output" =~ "$ctr1_id"  ]]
	[[ "$output" =~ "$ctr2_id"  ]]
	[[ "$output" =~ "$ctr3_id"  ]]
	run crictl stops "$pod_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl rms "$pod_id"
	echo "$output"
	[ "$status" -eq 0 ]
	cleanup_ctrs
	cleanup_pods
	stop_crio
}

@test "ctr metadata in list & status" {
	start_crio
	run crictl runs "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	pod_id="$output"
	run crictl create "$pod_id" "$TESTDATA"/container_config.json "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	ctr_id="$output"

	run crictl ps --id "$ctr_id" --output yaml
	echo "$output"
	[ "$status" -eq 0 ]
	# TODO: expected value should not hard coded here
	[[ "$output" =~ "name: container1" ]]
	[[ "$output" =~ "attempt: 1" ]]

	run crictl inspect "$ctr_id"
	echo "$output"
	[ "$status" -eq 0 ]
	# TODO: expected value should not hard coded here
	[[ "$output" =~ "Name: container1" ]]
	[[ "$output" =~ "Attempt: 1" ]]

	cleanup_ctrs
	cleanup_pods
	stop_crio
}

@test "ctr execsync conflicting with conmon flags parsing" {
	start_crio
	run crictl runs "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	pod_id="$output"
	run crictl create "$pod_id" "$TESTDATA"/container_redis.json "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	ctr_id="$output"
	run crictl start "$ctr_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl exec --sync "$ctr_id" sh -c "echo hello world"
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" == "hello world" ]]
	cleanup_ctrs
	cleanup_pods
	stop_crio
}

@test "ctr execsync" {
	start_crio
	run crictl runs "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	pod_id="$output"
	run crictl create "$pod_id" "$TESTDATA"/container_redis.json "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	ctr_id="$output"
	run crictl start "$ctr_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl exec --sync "$ctr_id" echo HELLO
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" == "HELLO" ]]
	run crictl exec --sync --timeout 1 "$ctr_id" sleep 3
	echo "$output"
	[[ "$output" =~ "command timed out" ]]
	[ "$status" -ne 0 ]
	run crictl stops "$pod_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl rms "$pod_id"
	echo "$output"
	[ "$status" -eq 0 ]
	cleanup_ctrs
	cleanup_pods
	stop_crio
}

@test "ctr device add" {
	start_crio
	run crictl runs "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	pod_id="$output"
	run crictl create "$pod_id" "$TESTDATA"/container_redis_device.json "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	ctr_id="$output"
	run crictl start "$ctr_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl exec --sync "$ctr_id" ls /dev/mynull
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "/dev/mynull" ]]
	run crictl stops "$pod_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl rms "$pod_id"
	echo "$output"
	[ "$status" -eq 0 ]
	cleanup_ctrs
	cleanup_pods
	stop_crio
}

@test "ctr execsync failure" {
	start_crio
	run crictl runs "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	pod_id="$output"
	run crictl create "$pod_id" "$TESTDATA"/container_redis.json "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	ctr_id="$output"
	run crictl start "$ctr_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl exec --sync "$ctr_id" doesnotexist
	echo "$output"
	[ "$status" -ne 0 ]

	cleanup_ctrs
	cleanup_pods
	stop_crio
}

@test "ctr execsync exit code" {
	start_crio
	run crictl runs "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	pod_id="$output"
	run crictl create "$pod_id" "$TESTDATA"/container_redis.json "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	ctr_id="$output"
	run crictl start "$ctr_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl exec --sync "$ctr_id" false
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "Exit code: 1" ]]
	cleanup_ctrs
	cleanup_pods
	stop_crio
}

@test "ctr execsync std{out,err}" {
	start_crio
	run crictl runs "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	pod_id="$output"
	run crictl create "$pod_id" "$TESTDATA"/container_redis.json "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	ctr_id="$output"
	run crictl start "$ctr_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl exec --sync "$ctr_id" echo hello0 stdout
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "hello0 stdout" ]]

	stderrconfig=$(cat "$TESTDATA"/container_config.json | python -c 'import json,sys;obj=json.load(sys.stdin);obj["image"]["image"] = "runcom/stderr-test"; obj["command"] = ["/bin/sleep", "600"]; json.dump(obj, sys.stdout)')
	echo "$stderrconfig" > "$TESTDIR"/container_config_stderr.json
	run crictl create "$pod_id" "$TESTDIR"/container_config_stderr.json "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	ctr_id="$output"
	run crictl start "$ctr_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl exec --sync "$ctr_id" stderr
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "this goes to stderr" ]]
	run crictl stops "$pod_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl rms "$pod_id"
	echo "$output"
	[ "$status" -eq 0 ]
	cleanup_ctrs
	cleanup_pods
	stop_crio
}
