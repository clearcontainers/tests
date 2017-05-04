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

package functional

import (
	. "github.com/clearcontainers/tests"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("start", func() {
	c := NewCommand(Runtime, "start")
	c.ExitCode = 1
	ret := c.Run()
	Context("without container id", func() {
		It("should NOT return 0", func() {
			Expect(ret).NotTo(Equal(0))
		})
		It("should report an error", func() {
			Expect(c.Stderr.Len()).NotTo(Equal(0))
		})
	})
})
