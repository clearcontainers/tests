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
	"io/ioutil"
	"os"
	"path"
)

var _ = Describe("cp", func() {
	var (
		args []string
		id   string
	)

	BeforeEach(func() {
		id = randomDockerName()
		args = []string{"run", "-td", "--name", id, Image, "sh"}
		runDockerCommand(0, args...)
	})

	AfterEach(func() {
		Expect(ContainerRemove(id)).To(BeTrue())
		Expect(ContainerExists(id)).NotTo(BeTrue())
	})

	Describe("cp with docker", func() {
		Context("check files after a docker cp", func() {
			It("has the corresponding files", func() {
				file, err := ioutil.TempFile(os.TempDir(), "file")
				Expect(err).ToNot(HaveOccurred())
				err = file.Close()
				Expect(err).ToNot(HaveOccurred())
				defer os.Remove(file.Name())
				Expect(file.Name()).To(BeAnExistingFile())
				args = []string{"cp", file.Name(), id + ":/root/"}
				runDockerCommand(0, args...)
				args = []string{"exec", id, "sh", "-c", "ls /root/"}
				stdout := runDockerCommand(0, args...)
				testFile := path.Base(file.Name())
				Expect(stdout).To(ContainSubstring(testFile))
			})
		})
	})
})
