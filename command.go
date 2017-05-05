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
	"bytes"
	"flag"
	"fmt"
	"os/exec"
	"syscall"
	"time"

	. "github.com/onsi/ginkgo"
)

// Runtime is the path of Clear Containers Runtime
var Runtime string

// Proxy is the path of Clear Containers Proxy
var Proxy string

// Shim is the path of Clear Containers Shim
var Shim string

// Timeout specifies the time limit in seconds for each test
var Timeout int

// Command contains the information of the command to run
type Command struct {
	// cmd exec.Cmd
	cmd *exec.Cmd

	// Stderr process's standard error
	Stderr bytes.Buffer

	// Stdout process's standard output
	Stdout bytes.Buffer

	// Timeout is the time limit of seconds of the command
	Timeout time.Duration

	// ExitCode is the expected exit code
	ExitCode int
}

func init() {
	flag.StringVar(&Runtime, "runtime", "cc-runtime", "Path of Clear Containers Runtime")
	flag.StringVar(&Proxy, "proxy", "cc-proxy", "Path of Clear Containers Proxy")
	flag.StringVar(&Shim, "shim", "cc-shim", "Path of Clear Containers Shim")
	flag.IntVar(&Timeout, "timeout", 5, "Time limit in seconds for each test")

	flag.Parse()
}

// NewCommand returns a new instance of Command
func NewCommand(path string, args ...string) *Command {
	c := new(Command)
	c.cmd = exec.Command(path, args...)
	c.cmd.Stderr = &c.Stderr
	c.cmd.Stdout = &c.Stdout
	c.ExitCode = 0
	c.Timeout = time.Duration(Timeout)

	return c
}

// Run runs a command returning its exit code
func (c *Command) Run() int {
	GinkgoWriter.Write([]byte(fmt.Sprintf("Running command '%s %s'\n", c.cmd.Path, c.cmd.Args)))
	c.cmd.Start()

	done := make(chan error)
	go func() { done <- c.cmd.Wait() }()

	var timeout <-chan time.Time
	if c.Timeout > 0 {
		timeout = time.After(c.Timeout * time.Second)
	}

	select {
	case <-timeout:
		GinkgoWriter.Write([]byte(fmt.Sprintf("Killing process timeout reached '%d' seconds\n", c.Timeout)))
		c.cmd.Process.Kill()
		return -1

	case err := <-done:
		if err != nil {
			GinkgoWriter.Write([]byte(fmt.Sprintf("command failed error '%s'\n", err)))
		}
		exitCode := c.cmd.ProcessState.Sys().(syscall.WaitStatus).ExitStatus()
		if exitCode != c.ExitCode {
			GinkgoWriter.Write([]byte(fmt.Sprintf("Exit code '%d' does not match with expected exit code '%d'\n", exitCode, c.ExitCode)))
		}
		return exitCode
	}
}
