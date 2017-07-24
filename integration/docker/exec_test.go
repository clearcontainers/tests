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

package docker

import (
	. "github.com/clearcontainers/tests"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("exec", func() {
	var (
		args     []string
		id       string
		exitCode int
		command  *Command
	)

	runCommand := func(args []string, expectedExitCode int) {
		command = NewCommand(Docker, args...)
		Expect(command).ToNot(BeNil())
		exitCode = command.Run()
		Expect(exitCode).To(Equal(expectedExitCode))
	}

	BeforeEach(func() {
		id = RandID(30)
		args = []string{"run", "-td", "--name", id, Image, "sh"}
		runCommand(args, 0)
	})

	AfterEach(func() {
		Expect(ContainerRemove(id)).To(BeTrue())
		Expect(ContainerExists(id)).NotTo(BeTrue())
	})

	Describe("exec with docker", func() {
		Context("modifying a container with exec", func() {
			It("should have the changes", func() {
				args = []string{"exec", "-d", id, "sh", "-c", "echo 'hello world' > file"}
				runCommand(args, 0)
				args = []string{"exec", id, "sh", "-c", "cat /file"}
				runCommand(args, 0)
				Expect(command.Stdout.String()).NotTo(BeEmpty())
				Expect(command.Stdout.String()).To(ContainSubstring("hello world"))
			})
		})

		Context("check exit code using exec", func() {
			It("should have the value assigned", func() {
				args = []string{"exec", id, "sh", "-c", "exit 42"}
				runCommand(args, 42)
			})
		})

		Context("check stdout forwarded using exec", func() {
			It("should displayed it", func() {
				args = []string{"exec", id, "sh", "-c", "ls /etc/resolv.conf 2>/dev/null"}
				runCommand(args, 0)
				Expect(command.Stdout.String()).To(ContainSubstring("/etc/resolv.conf"))
			})
		})

		Context("check stderr forwarded using exec", func() {
			It("should not exist", func() {
				args = []string{"exec", id, "sh", "-c", "ls /etc/foo >/dev/null"}
				runCommand(args, 1)
			})
		})
	})
})
