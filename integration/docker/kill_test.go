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
		args []string
		id   string
	)

	AfterEach(func() {
		Expect(ContainerRemove(id)).To(BeTrue())
		Expect(ContainerExists(id)).NotTo(BeTrue())
	})

	Describe("kill with docker", func() {
		Context("kill a container", func() {
			It("should assigned exited status", func() {
				id = randomDockerName()
				args = []string{"run", "-td", "--name", id, Image, "sh"}
				runDockerCommand(0, args...)
				Expect(ContainerRunning(id)).To(BeTrue())
				args = []string{"kill", id}
				stdout := runDockerCommand(0, args...)
				Expect(stdout).To(ContainSubstring(id))
				Expect(ContainerRunning(id)).To(BeFalse())
			})
		})
	})
})
