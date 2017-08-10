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

var _ = Describe("restart", func() {
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

	Describe("restart with docker", func() {
		Context("restart a container", func() {
			It("should be running", func() {
				Expect(ContainerStop(id)).To(BeTrue())
				Expect(ContainerRunning(id)).To(BeFalse())
				args = []string{"restart", id}
				runDockerCommand(0, args...)
				Expect(ContainerRunning(id)).To(BeTrue())
			})
		})
	})
})
