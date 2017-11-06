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
	"fmt"

	. "github.com/clearcontainers/tests"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("docker attach", func() {
	var (
		id                string
		exitCode          int
		containerExitCode int
	)

	BeforeEach(func() {
		containerExitCode = 13
		id = randomDockerName()
		_, _, exitCode = DockerRun("--name", id, "-d", Image, "sh", "-c",
			fmt.Sprintf("sleep 3 && exit %d", containerExitCode))
		Expect(exitCode).To(Equal(0))
	})

	AfterEach(func() {
		Expect(RemoveDockerContainer(id)).To(BeTrue())
		Expect(ExistDockerContainer(id)).NotTo(BeTrue())
	})

	Context("check attach functionality", func() {
		It("should attach exit code", func() {
			_, _, exitCode = DockerAttach(id)
			Expect(exitCode).To(Equal(containerExitCode))
		})
	})
})
