// Copyright (c) 2017 Intel Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package tests

import (
	"strings"
	"time"
)

const (
	// Docker command
	Docker = "docker"

	// Image used to run containers
	Image = "busybox"

	// AlpineImage is the alpine image
	AlpineImage = "alpine"
)

func runDockerCommandWithTimeout(timeout time.Duration, command string, args ...string) (string, string, int) {
	a := []string{command}
	a = append(a, args...)

	cmd := NewCommand(Docker, a...)
	cmd.Timeout = timeout

	return cmd.Run()
}

func runDockerCommand(command string, args ...string) (string, string, int) {
	return runDockerCommandWithTimeout(time.Duration(Timeout), command, args...)
}

// StatusDockerContainer returns the container status
func StatusDockerContainer(name string) string {
	args := []string{"-a", "-f", "name=" + name, "--format", "{{.Status}}"}

	stdout, _, exitCode := runDockerCommand("ps", args...)

	if exitCode != 0 || stdout == "" {
		return ""
	}

	state := strings.Split(stdout, " ")
	return state[0]
}

// IsRunningDockerContainer inspects a container
// returns true if is running
func IsRunningDockerContainer(name string) bool {
	stdout, _, exitCode := runDockerCommand("inspect", "--format={{.State.Running}}", name)

	if exitCode != 0 {
		return false
	}

	output := strings.TrimSpace(stdout)
	LogIfFail("container running: " + output)
	if output == "false" {
		return false
	}

	return true
}

// ExistDockerContainer returns true if any of next cases is true:
// - 'docker ps -a' command shows the container
// - the VM is running (qemu)
// else false is returned
func ExistDockerContainer(name string) bool {
	state := StatusDockerContainer(name)
	if state != "" {
		return true
	}

	return IsVMRunning(name)
}

// RemoveDockerContainer removes a container using docker rm -f
func RemoveDockerContainer(name string) bool {
	_, _, exitCode := DockerRm("-f", name)
	if exitCode != 0 {
		return false
	}

	return true
}

// StopDockerContainer stops a container
func StopDockerContainer(name string) bool {
	_, _, exitCode := DockerStop(name)
	if exitCode != 0 {
		return false
	}

	return true
}

// KillDockerContainer kills a container
func KillDockerContainer(name string) bool {
	_, _, exitCode := DockerKill(name)
	if exitCode != 0 {
		return false
	}

	return true
}

// DockerRm removes a container
func DockerRm(args ...string) (string, string, int) {
	return runDockerCommand("rm", args...)
}

// DockerStop stops a container
// returns true on success else false
func DockerStop(args ...string) (string, string, int) {
	// docker stop takes ~15 seconds
	return runDockerCommandWithTimeout(15, "stop", args...)
}

// DockerPull downloads the specific image
func DockerPull(args ...string) (string, string, int) {
	// 10 minutes should be enough to download a image
	return runDockerCommandWithTimeout(600, "pull", args...)
}

// DockerRun runs a container
func DockerRun(args ...string) (string, string, int) {
	return runDockerCommand("run", args...)
}

// DockerKill kills a container
func DockerKill(args ...string) (string, string, int) {
	return runDockerCommand("kill", args...)
}
