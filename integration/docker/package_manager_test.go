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
	"os"

	. "github.com/clearcontainers/tests"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("package manager update test", func() {
	var (
		id         string
		args       []string
		proxyVar   string
		proxyValue string
	)

	BeforeEach(func() {
		id = RandID(30)
		args = []string{}
		proxyVar = "http_proxy"
		proxyValue = os.Getenv(proxyVar)
		if proxyValue != "" {
			args = append(args, "-e", proxyVar+"="+proxyValue)
		}
	})

	AfterEach(func() {
		Expect(ExistDockerContainer(id)).NotTo(BeTrue())
	})

	Context("check apt-get update", func() {
		It("should not fail", func() {
			args = append(args, "--rm", "--name", id, DebianImage, "apt-get", "-y", "update")
			_, _, exitCode := DockerRun(args...)
			Expect(exitCode).To(BeZero())
		})
	})

	Context("check dnf update", func() {
		It("should not fail", func() {
			Skip("Issue: https://github.com/clearcontainers/runtime/issues/868")
			args = append(args, "-td", "--name", id, FedoraImage, "sh")
			_, _, exitCode := DockerRun(args...)
			Expect(exitCode).To(BeZero())

			if proxyValue != "" {
				_, _, exitCode = DockerExec(id, "sed", "-i", fmt.Sprintf("$ a proxy=%s", proxyValue), "/etc/dnf/dnf.conf")
				Expect(exitCode).To(BeZero())
			}

			_, _, exitCode = DockerExec(id, "dnf", "-y", "update")
			Expect(exitCode).To(BeZero())

			Expect(RemoveDockerContainer(id)).To(BeTrue())
		})
	})
})
