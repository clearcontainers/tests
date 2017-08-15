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
	"time"

	. "github.com/clearcontainers/tests"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("logs", func() {
	var (
		args []string
		id   string
	)

	BeforeEach(func() {
		id = randomDockerName()
		args = []string{"run", "-td", "--name", id, Image, "sh", "-c", "'echo hello'"}
		runDockerCommand(0, args...)
		// Issue https://github.com/clearcontainers/runtime/issues/375
		time.Sleep(2 * time.Second)
	})

	AfterEach(func() {
		Expect(RemoveDockerContainer(id)).To(BeTrue())
		Expect(ExistDockerContainer(id)).NotTo(BeTrue())
	})

	Describe("logs with docker", func() {
		Context("check logs functionality", func() {
			It("should work", func() {
				args = []string{"logs", id}
				stdout := runDockerCommand(0, args...)
				Expect(stdout).To(ContainSubstring("hello"))
			})
		})
	})
})
