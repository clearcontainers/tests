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

var _ = Describe("user", func() {
	var (
		args []string
		id   string
	)

	BeforeEach(func() {
		id = randomDockerName()
	})

	AfterEach(func() {
		Expect(ContainerRemove(id)).To(BeTrue())
		Expect(ContainerExists(id)).NotTo(BeTrue())
	})

	Describe("set user with docker", func() {
		Context("run as non-root user", func() {
			It("should display the non-root user", func() {
				Skip("Issue https://github.com/clearcontainers/runtime/issues/386")
				args = []string{"run", "--name", id, "-u", "postgres", "postgres", "whoami"}
				stdout := runDockerCommand(0, args...)
				Expect(stdout).To(ContainSubstring("postgres"))
			})
		})

		Context("run as root user", func() {
			It("should display root user", func() {
				args = []string{"run", "--name", id, "-u", "root:root", "postgres", "whoami"}
				stdout := runDockerCommand(0, args...)
				Expect(stdout).To(ContainSubstring("root"))
			})
		})
	})
})
