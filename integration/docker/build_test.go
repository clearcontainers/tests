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
	"os"
	"path/filepath"
)

const dockerFile = "src/github.com/clearcontainers/tests/Dockerfiles/BuildTest/."

var _ = Describe("build", func() {
	var (
		args      []string
		id        string
		imageName string = "test"
		stdout    string
		exitCode  int
	)

	BeforeEach(func() {
		id = randomDockerName()
	})

	AfterEach(func() {
		_, _, exitCode = DockerRmi(imageName)
		Expect(exitCode).To(Equal(0))
		Expect(ExistDockerContainer(id)).NotTo(BeTrue())
	})

	Describe("build with docker", func() {
		Context("docker build env vars", func() {
			It("should display env vars", func() {
				gopath := os.Getenv("GOPATH")
				entirePath := filepath.Join(gopath, dockerFile)
				args = []string{"-t", imageName, entirePath}
				_, _, exitCode = DockerBuild(args...)
				Expect(exitCode).To(Equal(0))
				args = []string{"--rm", "-t", "--name", id, imageName, "sh", "-c", "'env'"}
				stdout, _, exitCode = DockerRun(args...)
				Expect(exitCode).To(Equal(0))
				Expect(stdout).To(ContainSubstring("test_env_vars"))
			})
		})
	})
})
