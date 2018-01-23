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

function setup() {
	start_crio
}

function teardown() {
	stop_crio
	sudo umount "$TESTDIR/crio/overlay"
	cleanup_test
}

@test "ctr not found correct error message" {
	run crictl inspect randomid
	echo "$output"
	[ "$status" -eq 1 ]
	[[ "$output" =~ "container with ID starting with randomid not found" ]]
}

@test "ctr termination reason Completed" {
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
	sleep 5
	run crictl inspect --output yaml "$ctr_id"
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "reason: Completed" ]]

	cleanup_ctrs
	cleanup_pods
}

@test "ctr termination reason Error" {
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
	run crictl inspect --output yaml "$ctr_id"
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" =~ "reason: Error" ]]

	cleanup_ctrs
	cleanup_pods
}

@test "ctr remove" {
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
}

@test "ctr lifecycle" {
	run crictl runs "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	pod_id="$output"
	run crictl sandboxes --quiet
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl create "$pod_id" "$TESTDATA"/container_redis.json "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	ctr_id="$output"
	run crictl ps --quiet
	echo "$output"
	[ "$status" -eq 0 ]
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
	run crictl stop "$ctr_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl inspect "$ctr_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl ps --quiet
	echo "$output"
	[ "$status" -eq 0 ]
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
	run crictl ps --quiet
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl rms "$pod_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl sandboxes --quiet
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl ps --quiet
	echo "$output"
	[ "$status" -eq 0 ]
	cleanup_ctrs
	cleanup_pods
}

@test "ctr logging" {
	run crictl runs "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	pod_id="$output"
	run crictl sandboxes --quiet
	echo "$output"
	[ "$status" -eq 0 ]

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
	grep -E "^[^\n]+ stdout . here is some output$" "$logpath"
	grep -E "^[^\n]+ stderr . and some from stderr$" "$logpath"

	run crictl stops "$pod_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl rms "$pod_id"
	echo "$output"
	[ "$status" -eq 0 ]

	cleanup_ctrs
	cleanup_pods
}

@test "ctr logging [tty=true]" {
	run crictl runs "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	pod_id="$output"
	run crictl sandboxes --quiet
	echo "$output"
	[ "$status" -eq 0 ]

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
	grep --binary -P "^[^\n]+ stdout . here is some output\x0d$" "$logpath"

	run crictl stops "$pod_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl rms "$pod_id"
	echo "$output"
	[ "$status" -eq 0 ]

	cleanup_ctrs
	cleanup_pods
}

@test "ctr list filtering" {
	sandbox1_config=$(mktemp --tmpdir sandbox1-config.XXXXXX.json)
	cp "$TESTDATA"/sandbox_config.json "$sandbox1_config"
	sed -i 's|podsandbox1|podsandboxtest1|' "$sandbox1_config"
	run crictl runs "$sandbox1_config"
	echo "$output"
	[ "$status" -eq 0 ]
	pod1_id="$output"
	ctr1_config=$(mktemp --tmpdir ctr1-config.XXXXXX.json)
	cp "$TESTDATA"/container_redis.json "$ctr1_config"
	sed -i 's|podsandbox1-redis|podsandboxtest1-redis|' "$ctr1_config"
	run crictl create "$pod1_id" "$ctr1_config" "$sandbox1_config"
	echo "$output"
	[ "$status" -eq 0 ]
	ctr1_id="$output"
	run crictl start "$ctr1_id"
	echo "$output"
	[ "$status" -eq 0 ]
	sandbox2_config=$(mktemp --tmpdir sandbox2-config.XXXXXX.json)
	cp "$TESTDATA"/sandbox_config.json "$sandbox2_config"
	sed -i 's|podsandbox1|podsandboxtest2|' "$sandbox2_config"
	run crictl runs "$sandbox2_config"
	echo "$output"
	[ "$status" -eq 0 ]
	pod2_id="$output"
	ctr2_config=$(mktemp --tmpdir ctr2-config.XXXXXX.json)
	cp "$TESTDATA"/container_redis.json "$ctr2_config"
	sed -i 's|podsandbox1-redis|podsandboxtest2-redis|' "$ctr2_config"
	run crictl create "$pod2_id" "$ctr2_config" "$sandbox2_config"
	echo "$output"
	[ "$status" -eq 0 ]
	ctr2_id="$output"
	sandbox3_config=$(mktemp --tmpdir sandbox3-config.XXXXXX.json)
	cp "$TESTDATA"/sandbox_config.json "$sandbox3_config"
	sed -i 's|podsandbox1|podsandboxtest3|' "$sandbox3_config"
	run crictl runs "$sandbox3_config"
	echo "$output"
	[ "$status" -eq 0 ]
	pod3_id="$output"
	ctr3_config=$(mktemp --tmpdir ctr3-config.XXXXXX.json)
	cp "$TESTDATA"/container_redis.json "$ctr3_config"
	sed -i 's|podsandbox1-redis|podsandboxtest3-redis|' "$ctr3_config"
	run crictl create "$pod3_id" "$ctr3_config" "$sandbox3_config"
	echo "$output"
	[ "$status" -eq 0 ]
	ctr3_id="$output"
	run crictl start "$ctr3_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl stop "$ctr3_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl ps --quiet --id "$ctr1_id"
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" != "" ]]
	[[ "$output" =~ "$ctr1_id"  ]]
	run crictl ps --quiet --id "${ctr1_id:0:4}"
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" != "" ]]
	[[ "$output" =~ "$ctr1_id"  ]]
	run crictl ps --quiet --id "$ctr2_id" --sandbox "$pod2_id"
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" != "" ]]
	[[ "$output" =~ "$ctr2_id"  ]]
	run crictl ps --quiet --id "$ctr2_id" --sandbox "$pod3_id"
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" == "" ]]
	run crictl ps --quiet --state created
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" != "" ]]
	[[ "$output" =~ "$ctr2_id"  ]]
	run crictl ps --quiet --state running
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" != "" ]]
	[[ "$output" =~ "$ctr1_id"  ]]
	run crictl ps --quiet --state stopped
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" != "" ]]
	[[ "$output" =~ "$ctr3_id"  ]]
	run crictl ps --quiet --sandbox "$pod1_id"
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" != "" ]]
	[[ "$output" =~ "$ctr1_id"  ]]
	run crictl ps --quiet --sandbox "$pod2_id"
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" != "" ]]
	[[ "$output" =~ "$ctr2_id"  ]]
	run crictl ps --quiet --sandbox "$pod3_id"
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" != "" ]]
	[[ "$output" =~ "$ctr3_id"  ]]
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
}

@test "ctr list label filtering" {
	run crictl runs "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	pod_id="$output"

	ctr1_config=$(mktemp --tmpdir ctr1-config.XXXXXX.json)
	cp "$TESTDATA"/container_redis.json "$ctr1_config"
	sed -i 's/podsandbox1-redis/podsandboxtest1-redis/' "$ctr1_config"
	sed -i '/labels/a "a": "b",' "$ctr1_config"
	sed -i '/labels/a "c": "d",' "$ctr1_config"
	sed -i '/labels/a "e": "f",' "$ctr1_config"
	run crictl create "$pod_id" "$ctr1_config" "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	ctr1_id="$output"
	ctr2_config=$(mktemp --tmpdir ctr2-config.XXXXXX.json)
	cp "$TESTDATA"/container_redis.json "$ctr2_config"
	sed -i 's/podsandbox1-redis/podsandboxtest2-redis/' "$ctr2_config"
	sed -i '/labels/a "a": "b",' "$ctr2_config"
	sed -i '/labels/a "c": "d",' "$ctr2_config"
	run crictl create "$pod_id" "$ctr2_config" "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	ctr2_id="$output"
	ctr3_config=$(mktemp --tmpdir ctr3-config.XXXXXX.json)
	cp "$TESTDATA"/container_redis.json "$ctr3_config"
	sed -i 's/podsandbox1-redis/podsandboxtest3-redis/' "$ctr3_config"
	sed -i '/labels/a "a": "b",' "$ctr3_config"
	run crictl create "$pod_id" "$ctr3_config" "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	ctr3_id="$output"
	run crictl ps --quiet --label "tier=backend" --label "a=b" --label "c=d" --label "e=f"
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" != "" ]]
	[[ "$output" =~ "$ctr1_id"  ]]
	run crictl ps --quiet --label "tier=frontend"
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" == "" ]]
	run crictl ps --quiet --label "a=b" --label "c=d"
	echo "$output"
	[ "$status" -eq 0 ]
	[[ "$output" != "" ]]
	[[ "$output" =~ "$ctr1_id"  ]]
	[[ "$output" =~ "$ctr2_id"  ]]
	run crictl ps --quiet --label "a=b"
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
}

@test "ctr metadata in ps and inspect" {
	run crictl runs "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	pod_id="$output"
	run crictl create "$pod_id" "$TESTDATA"/container_config.json "$TESTDATA"/sandbox_config.json
	echo "$output"
	[ "$status" -eq 0 ]
	ctr_id="$output"

	run crictl ps -v --id "$ctr_id"
	echo "$output"
	[ "$status" -eq 0 ]
	# TODO: expected value should not hard coded here
	[[ "$output" =~ "Name: container1" ]]
	[[ "$output" =~ "Attempt: 1" ]]

	run crictl inspect "$ctr_id"
	echo "$output"
	[ "$status" -eq 0 ]
	# TODO: expected value should not hard coded here
	[[ "$output" =~ "Name: container1" ]]
	[[ "$output" =~ "Attempt: 1" ]]

	cleanup_ctrs
	cleanup_pods
}

@test "ctr exec sync conflicting with conmon flags parsing" {
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
	[[ "$output" =~ "hello world" ]]
	cleanup_ctrs
	cleanup_pods
}

@test "ctr exec sync" {
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
	[[ "$output" =~ "HELLO" ]]
	run crictl exec --sync --timeout 1 "$ctr_id" sleep 10
	echo "$output"
	[[ "$output" =~ "command timed out" ]]
	run crictl stops "$pod_id"
	echo "$output"
	[ "$status" -eq 0 ]
	run crictl rms "$pod_id"
	echo "$output"
	[ "$status" -eq 0 ]
	cleanup_ctrs
	cleanup_pods
}

@test "ctr device add" {
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
}

@test "ctr execsync failure" {
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
}

@test "ctr execsync exit code" {
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
}

@test "ctr execsync std{out,err}" {
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
}
