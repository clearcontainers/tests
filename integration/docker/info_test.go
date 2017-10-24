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

var _ = Describe("info", func() {
	var (
		stdout   string
		exitCode int
	)

	Context("docker info", func() {
		It("should has a runtime information", func() {
			stdout, _, exitCode = DockerInfo()
			Expect(exitCode).To(Equal(0))
			Expect(stdout).To(ContainSubstring("Default Runtime: " + Runtime))
		})
	})
})
