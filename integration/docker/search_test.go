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

var _ = Describe("docker search", func() {
	var (
		args []string
	)

	Context("search an image", func() {
		It("should filter the requests", func() {
			args = []string{"--filter", "is-official=true", "--filter=stars=3", Image}
			stdout, _, exitCode := DockerSearch(args...)
			Expect(exitCode).To(Equal(0))
			Expect(stdout).To(ContainSubstring(Image))
		})
	})
})
