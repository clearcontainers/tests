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
)

const (
	// Docker command
	Docker = "docker"

	// Image used to run containers
	Image = "busybox"
)

// ContainerStatus returns the container status
func ContainerStatus(name string) string {
	args := []string{"ps", "-a", "-f", "name=" + name, "--format", "{{.Status}}"}

	cmd := NewCommand(Docker, args...)

	exitCode := cmd.Run()
	if exitCode != 0 {
		return ""
	}

	stdout := cmd.Stdout.String()
	if stdout == "" {
		return ""
	}

	state := strings.Split(stdout, " ")
	return state[0]
}

// ContainerExists returns true if any of next cases is true:
// - 'docker ps -a' command shows the container
// - the VM is running (qemu)
// else false is returned
func ContainerExists(name string) bool {
	state := ContainerStatus(name)
	if state != "" {
		return true
	}

	return IsVMRunning(name)
}

// ContainerRemove removes a container
func ContainerRemove(name string) bool {
	args := []string{"rm", "-f", name}

	cmd := NewCommand(Docker, args...)
	if cmd == nil {
		return false
	}

	if cmd.Run() != 0 {
		LogIfFail(cmd.Stderr.String())
		return false
	}

	return true
}
