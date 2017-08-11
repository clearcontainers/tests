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

var _ = Describe("commit", func() {
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
		Expect(RemoveDockerContainer(id)).To(BeTrue())
		Expect(ExistDockerContainer(id)).NotTo(BeTrue())
	})

	Describe("commit with docker", func() {
		Context("commit a container with new configurations", func() {
			It("should have the new configurations", func() {
				imageName := "test/container-test"
				args = []string{"commit", "-m", "test_commit", id, imageName}
				runDockerCommand(0, args...)
				stdout := runDockerCommand(0, "images")
				Expect(stdout).To(ContainSubstring(imageName))
				args = []string{"rmi", imageName}
				runDockerCommand(0, args...)
				stdout = runDockerCommand(0, "images")
				Expect(stdout).NotTo(ContainSubstring(imageName))
			})
		})
	})
})
