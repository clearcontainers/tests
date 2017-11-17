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

var _ = Describe("docker env", func() {
	var (
		id       string
		hostname string
		stdout   string
		exitCode int
	)

	AfterEach(func() {
		Expect(RemoveDockerContainer(id)).To(BeTrue())
		Expect(ExistDockerContainer(id)).NotTo(BeTrue())
	})

	Context("check that required env variables are set", func() {
		It("should have path, hostname, home", func() {
			id = randomDockerName()
			hostname = "container"
			stdout, _, exitCode = DockerRun("--name", id, "-h", hostname, Image, "env")
			Expect(exitCode).To(Equal(0))
			Expect(stdout).To(ContainSubstring("PATH"))
			Expect(stdout).To(ContainSubstring("HOME"))
			Expect(stdout).To(ContainSubstring("HOSTNAME=" + hostname))
		})
	})

	Context("set environment variables", func() {
		It("should have the environment variables", func() {
			id = randomDockerName()
			envar := "ENVAR=VALUE_ENVAR"
			stdout, _, exitCode = DockerRun("-e", envar, "--name", id, Image, "env")
			Expect(exitCode).To(Equal(0))
			Expect(stdout).To(ContainSubstring(envar))
		})
	})
})
