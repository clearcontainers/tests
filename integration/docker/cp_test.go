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
	"io/ioutil"
	"os"
	"path"

	. "github.com/clearcontainers/tests"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("docker cp", func() {
	var (
		id       string
		exitCode int
		stdout   string
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

	Context("check files after a docker cp", func() {
		It("should have the corresponding files", func() {
			file, err := ioutil.TempFile(os.TempDir(), "file")
			Expect(err).ToNot(HaveOccurred())
			err = file.Close()
			Expect(err).ToNot(HaveOccurred())
			defer os.Remove(file.Name())
			Expect(file.Name()).To(BeAnExistingFile())

			_, _, exitCode = DockerCp(file.Name(), id+":/root/")
			Expect(exitCode).To(Equal(0))

			stdout, _, exitCode = DockerExec(id, "ls", "/root/")
			Expect(exitCode).To(Equal(0))
			testFile := path.Base(file.Name())
			Expect(stdout).To(ContainSubstring(testFile))
		})
	})
})
