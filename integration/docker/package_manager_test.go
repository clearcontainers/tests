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
	"os"

	. "github.com/clearcontainers/tests"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("package manager apt-get", func() {
	var (
		id         string
		args       []string
		proxyVar   string
		proxyValue string
	)

	BeforeEach(func() {
		id = RandID(30)
		proxyVar = "http_proxy"
		proxyValue = os.Getenv(proxyVar)
		if proxyValue != "" {
			args = append(args, "-e", proxyVar+"="+proxyValue)
		}
		args = append(args, "--rm", "--name", id, DebianImage, "apt-get", "update")
	})

	AfterEach(func() {
		Expect(ExistDockerContainer(id)).NotTo(BeTrue())
	})

	Context("check apt-get update", func() {
		It("should not fail", func() {
			_, _, exitCode := DockerRun(args...)
			Expect(exitCode).To(BeZero())
		})
	})
})
