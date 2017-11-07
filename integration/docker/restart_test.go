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
		_, _, exitCode := DockerRun("-td", "--name", id, Image, "sh")
		Expect(exitCode).To(Equal(0))
	})

	AfterEach(func() {
		Expect(RemoveDockerContainer(id)).To(BeTrue())
		Expect(ExistDockerContainer(id)).NotTo(BeTrue())
	})

	Describe("restart with docker", func() {
		Context("restart a container", func() {
			It("should be running", func() {
				Expect(StopDockerContainer(id)).To(BeTrue())
				Expect(WaitForRunningDockerContainer(id, false)).To(BeNil())
				args = []string{"restart", id}
				runDockerCommand(0, args...)
				Expect(WaitForRunningDockerContainer(id, true)).To(BeNil())
			})
		})
	})
})
