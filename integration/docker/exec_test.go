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
		args []string
		id   string
	)

	BeforeEach(func() {
		id = randomDockerName()
		args = []string{"run", "-td", "--name", id, Image, "sh"}
		runDockerCommand(0, args...)
	})

	AfterEach(func() {
		Expect(ContainerRemove(id)).To(BeTrue())
		Expect(ContainerExists(id)).NotTo(BeTrue())
	})

	Describe("exec with docker", func() {
		Context("modifying a container with exec", func() {
			It("should have the changes", func() {
				args = []string{"exec", "-d", id, "sh", "-c", "echo 'hello world' > file"}
				runDockerCommand(0, args...)
				args = []string{"exec", id, "sh", "-c", "cat /file"}
				stdout := runDockerCommand(0, args...)
				Expect(stdout).NotTo(BeEmpty())
				Expect(stdout).To(ContainSubstring("hello world"))
			})
		})

		Context("check exit code using exec", func() {
			It("should have the value assigned", func() {
				args = []string{"exec", id, "sh", "-c", "exit 42"}
				runDockerCommand(42, args...)
			})
		})

		Context("check stdout forwarded using exec", func() {
			It("should displayed it", func() {
				args = []string{"exec", id, "sh", "-c", "ls /etc/resolv.conf 2>/dev/null"}
				stdout := runDockerCommand(0, args...)
				Expect(stdout).To(ContainSubstring("/etc/resolv.conf"))
			})
		})

		Context("check stderr forwarded using exec", func() {
			It("should not exist", func() {
				args = []string{"exec", id, "sh", "-c", "ls /etc/foo >/dev/null"}
				runDockerCommand(1, args...)
			})
		})
	})
})
