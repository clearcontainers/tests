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

var _ = Describe("network", func() {
	var (
		args        []string
		networkName string = "my-bridge-network"
	)

	AfterEach(func() {
		_, _, exitCode := DockerNetwork("rm", networkName)
		Expect(exitCode).To(Equal(0))
		stdout, _, exitCode := DockerNetwork("ls")
		Expect(exitCode).To(Equal(0))
		Expect(stdout).NotTo(ContainSubstring(networkName))
	})

	Describe("network with docker", func() {
		Context("create network", func() {
			It("should display the network's name", func() {
				args = []string{"create", "-d", "bridge", networkName}
				_, _, exitCode := DockerNetwork(args...)
				Expect(exitCode).To(Equal(0))
				_, _, exitCode = DockerNetwork("inspect", networkName)
				Expect(exitCode).To(Equal(0))
			})
		})
	})
})
