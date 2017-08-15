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

var _ = Describe("docker exec", func() {
	var (
		args     []string
		id       string
		exitCode int
		stdout   string
		stderr   string
	)

	BeforeEach(func() {
		id = randomDockerName()
		_, _, exitCode = DockerRun("-td", "--name", id, Image, "sh")
		Expect(exitCode).To(Equal(0))
	})

	AfterEach(func() {
		Expect(RemoveDockerContainer(id)).To(BeTrue())
		Expect(ExistDockerContainer(id)).NotTo(BeTrue())
	})

	Context("modifying a container with exec", func() {
		It("should have the changes", func() {
			args = []string{"-d", id, "sh", "-c", "echo 'hello world' > file"}
			_, _, exitCode = DockerExec(args...)
			Expect(exitCode).To(Equal(0))

			args = []string{id, "sh", "-c", "cat /file"}
			stdout, _, exitCode = DockerExec(args...)
			Expect(exitCode).To(Equal(0))
			Expect(stdout).NotTo(BeEmpty())
			Expect(stdout).To(ContainSubstring("hello world"))
		})
	})

	Context("check exit code using exec", func() {
		It("should have the value assigned", func() {
			_, _, exitCode = DockerExec(id, "sh", "-c", "exit 42")
			Expect(exitCode).To(Equal(42))
		})
	})

	Context("check stdout forwarded using exec", func() {
		It("should displayed it", func() {
			args = []string{id, "sh", "-c", "ls /etc/resolv.conf 2>/dev/null"}
			stdout, _, exitCode = DockerExec(args...)
			Expect(exitCode).To(Equal(0))
			Expect(stdout).To(ContainSubstring("/etc/resolv.conf"))
		})
	})

	Context("check stderr forwarded using exec", func() {
		It("should not exist", func() {
			args = []string{id, "sh", "-c", "ls /etc/foo >/dev/null"}
			stdout, stderr, exitCode = DockerExec(args...)
			Expect(exitCode).To(Equal(1))
			Expect(stdout).To(BeEmpty())
			Expect(stderr).ToNot(BeEmpty())
		})
	})
})
