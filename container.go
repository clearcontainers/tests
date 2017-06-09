/// Copyright (c) 2017 Intel Corporation
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
	"bytes"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
)

// Container represents a clear container
type Container struct {
	// Bundle contains the container information
	// if nil then try to run the container without --bundle option
	Bundle *Bundle

	// Console pty slave path
	// if nil then try to run the container without --console option
	Console *string

	// PidFile where process id is written
	// if nil then try to run the container without --pid-file option
	PidFile *string

	// Debug enables debug output
	Debug bool

	// LogFile where debug information is written
	// if nil then try to run the container without --log option
	LogFile *string

	// ID of the container
	// if nil then try to run the container without container ID
	ID *string
}

// NewContainer returns a new Container
func NewContainer(workload []string) (*Container, error) {
	b, err := NewBundle(workload)
	if err != nil {
		return nil, err
	}

	console := "/dev/ptmx"
	pidFile := filepath.Join(b.Path, "pid")
	logFile := filepath.Join(b.Path, "log")
	id := RandID(20)

	return &Container{
		Bundle:  b,
		Console: &console,
		PidFile: &pidFile,
		Debug:   true,
		LogFile: &logFile,
		ID:      &id,
	}, nil
}

// Run the container
// calls to run command returning its stdout, stderr and exit code
func (c *Container) Run() (bytes.Buffer, bytes.Buffer, int) {
	args := []string{}

	if c.Debug {
		args = append(args, "--debug")
	}

	if c.LogFile != nil {
		args = append(args, "--log", *c.LogFile)
	}

	args = append(args, "run")

	if c.Bundle != nil {
		args = append(args, "--bundle", c.Bundle.Path)
	}

	if c.Console != nil {
		args = append(args, "--console", *c.Console)
	}

	if c.PidFile != nil {
		args = append(args, "--pid-file", *c.PidFile)
	}

	if c.ID != nil {
		args = append(args, *c.ID)
	}

	cmd := NewCommand(Runtime, args...)
	ret := cmd.Run()

	return cmd.Stdout, cmd.Stderr, ret
}

// Delete the container
// calls to delete command returning its stdout, stderr and exit code
func (c *Container) Delete(force bool) (bytes.Buffer, bytes.Buffer, int) {
	args := []string{"delete"}

	if force {
		args = append(args, "--force")
	}

	if c.ID != nil {
		args = append(args, *c.ID)
	}

	cmd := NewCommand(Runtime, args...)
	ret := cmd.Run()

	return cmd.Stdout, cmd.Stderr, ret
}

// Kill the container
// calls to kill command returning its stdout, stderr and exit code
func (c *Container) Kill(all bool, signal interface{}) (bytes.Buffer, bytes.Buffer, int) {
	args := []string{"kill"}

	if all {
		args = append(args, "--all")
	}

	if c.ID != nil {
		args = append(args, *c.ID)
	}

	switch t := signal.(type) {
	case syscall.Signal:
		args = append(args, strconv.Itoa(int(t)))
	case string:
		args = append(args, t)
	}

	cmd := NewCommand(Runtime, args...)
	ret := cmd.Run()

	return cmd.Stdout, cmd.Stderr, ret
}

// List the containers
// calls to list command returning its stdout, stderr and exit code
func (c *Container) List(format string, quiet bool, all bool) (bytes.Buffer, bytes.Buffer, int) {
	args := []string{"list"}

	if format != "" {
		args = append(args, "--format", format)
	}

	if quiet {
		args = append(args, "--quiet")
	}

	if all {
		args = append(args, "--all")
	}

	cmd := NewCommand(Runtime, args...)
	ret := cmd.Run()

	return cmd.Stdout, cmd.Stderr, ret
}

// SetWorkload sets a workload for the container
func (c *Container) SetWorkload(workload []string) error {
	c.Bundle.Config.Process.Args = workload
	return c.Bundle.Save()
}

// RemoveOption removes a specific option
// container will run without the specific option
func (c *Container) RemoveOption(option string) error {
	switch option {
	case "--bundle", "-b":
		defer c.Bundle.Remove()
		c.Bundle = nil
	case "--console":
		c.Console = nil
	case "--pid-file":
		c.PidFile = nil
	default:
		return fmt.Errorf("undefined option '%s'", option)
	}

	return nil
}

// Cleanup removes files and directories created by the container
// returns an error if a file or directory can not be removed
func (c *Container) Cleanup() error {
	if c.Bundle != nil {
		return c.Bundle.Remove()
	}

	return nil
}

// Exist returns true if any of next cases is true:
// - list command shows the container
// - the process id specified in the pid file is running (cc-shim)
// - the VM is running (qemu)
// else false is returned
func (c *Container) Exist() bool {
	return c.isListed() || c.isWorkloadRunning() || c.isVMRunning()
}

func (c *Container) isListed() bool {
	if c.ID == nil {
		return false
	}

	stdout, _, ret := c.List("", true, false)
	if ret != 0 {
		return false
	}

	return strings.Contains(stdout.String(), *c.ID)
}

func (c *Container) isWorkloadRunning() bool {
	if c.PidFile == nil {
		return false
	}

	content, err := ioutil.ReadFile(*c.PidFile)
	if err != nil {
		return false
	}

	if _, err := os.Stat(fmt.Sprintf("/proc/%s/stat", string(content))); os.IsNotExist(err) {
		return false
	}

	return true
}

func (c *Container) isVMRunning() bool {
	// FIXME: find a way to check if the VM is still running
	return false
}
