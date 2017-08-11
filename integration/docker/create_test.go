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

var _ = Describe("create", func() {
	var (
		args []string
		id   string
	)

	AfterEach(func() {
		Expect(RemoveDockerContainer(id)).To(BeTrue())
		Expect(ExistDockerContainer(id)).NotTo(BeTrue())
	})

	Describe("create with docker", func() {
		Context("check create functionality", func() {
			It("create a container", func() {
				id = randomDockerName()
				args = []string{"create", "-t", "--name", id, Image}
				runDockerCommand(0, args...)
				args = []string{"ps", "--filter", "status=created"}
				stdout := runDockerCommand(0, args...)
				Expect(stdout).To(ContainSubstring(id))
			})
		})
	})
})
