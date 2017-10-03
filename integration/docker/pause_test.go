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

var _ = Describe("pause", func() {
	var (
		id string
	)

	AfterEach(func() {
		Expect(RemoveDockerContainer(id)).To(BeTrue())
		Expect(ExistDockerContainer(id)).NotTo(BeTrue())
	})

	Describe("pause with docker", func() {
		Context("check pause functionality", func() {
			It("should not be running", func() {
				id = randomDockerName()
				_, _, exitCode := DockerRun("-td", "--name", id, Image, "sh")
				Expect(exitCode).To(Equal(0))
				_, _, exitCode = DockerPause(id)
				Expect(exitCode).To(Equal(0))
				stdout, _, exitCode := DockerPs("-a", "--filter", "status=paused", "--filter", "name="+id)
				Expect(exitCode).To(Equal(0))
				Expect(stdout).To(ContainSubstring("Paused"))
				_, _, exitCode = DockerUnpause(id)
				Expect(exitCode).To(Equal(0))
				stdout, _, exitCode = DockerPs("-a", "--filter", "status=running", "--filter", "name="+id)
				Expect(exitCode).To(Equal(0))
				Expect(stdout).To(ContainSubstring("Up"))
			})
		})
	})
})
