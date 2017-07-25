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

var _ = Describe("kill", func() {
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

	AfterEach(func() {
		Expect(ContainerRemove(id)).To(BeTrue())
		Expect(ContainerExists(id)).NotTo(BeTrue())
	})

	Describe("kill with docker", func() {
		Context("kill a container", func() {
			It("should assigned exited status", func() {
				id = RandID(30)
				args = []string{"run", "-td", "--name", id, Image, "sh"}
				runCommand(args, 0)
				args = []string{"inspect", "--format='{{.State.Running}}'", id}
				runCommand(args, 0)
				Expect(command.Stdout.String()).To(ContainSubstring("true"))
				args = []string{"kill", id}
				runCommand(args, 0)
				Expect(command.Stdout.String()).To(ContainSubstring(id))
				args = []string{"inspect", "--format='{{.State.Running}}'", id}
				runCommand(args, 0)
				Expect(command.Stdout.String()).To(ContainSubstring("false"))
			})
		})
	})
})
