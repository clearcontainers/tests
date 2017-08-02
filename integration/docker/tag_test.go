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

var _ = Describe("tag", func() {
	var (
		args    []string
		id      string
		tagName string
	)

	BeforeEach(func() {
		id = randomDockerName()
		args = []string{"run", "-td", "--name", id, Image, "sh"}
		runDockerCommand(0, args...)
	})

	AfterEach(func() {
		Expect(ContainerRemove(id)).To(BeTrue())
		Expect(ContainerExists(id)).NotTo(BeTrue())
		args = []string{"rmi", tagName}
		runDockerCommand(0, args...)
	})

	Describe("tag with docker", func() {
		Context("tag a container", func() {
			It("has the tag", func() {
				tagName = "container"
				args = []string{"tag", Image, tagName}
				runDockerCommand(0, args...)
				stdout := runDockerCommand(0, "images")
				Expect(stdout).To(ContainSubstring(tagName))
			})
		})
	})
})
