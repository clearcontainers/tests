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

var _ = Describe("docker create", func() {
	var (
		id       string
		exitCode int
		stdout   string
	)

	BeforeEach(func() {
		id = randomDockerName()
	})

	AfterEach(func() {
		Expect(RemoveDockerContainer(id)).To(BeTrue())
		Expect(ExistDockerContainer(id)).NotTo(BeTrue())
	})

	Context("check create functionality", func() {
		It("create a container", func() {
			_, _, exitCode = DockerCreate("-t", "--name", id, Image)
			Expect(exitCode).To(Equal(0))

			stdout, _, exitCode = DockerPs("--filter", "status=created")
			Expect(exitCode).To(Equal(0))
			Expect(stdout).To(ContainSubstring(id))
		})
	})

	Context("check create --read-only option", func() {
		It("should not allowed to modify the filesystem", func() {
			Skip("Issue https://github.com/clearcontainers/runtime/issues/614")
			_, _, exitCode = DockerCreate("--name", id, "--read-only", Image, "sh", "-c", "sleep 30")
			Expect(exitCode).To(Equal(0))

			_, _, exitCode = DockerStart(id)
			Expect(exitCode).To(Equal(0))

			args := []string{id, "sh", "-c", "ls -ld /root; touch /root/foo.txt && ls -l /root/foo.txt"}
			_, _, exitCode = DockerExec(args...)
			Expect(exitCode).To(Equal(1))
                })
        })
})
