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

	. "github.com/clearcontainers/tests"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

var _ = Describe("load", func() {
	var (
		args      []string
		id        string
		imageName string
	)

	BeforeEach(func() {
		id = randomDockerName()
		args = []string{"run", "-td", "--name", id, Image}
		runDockerCommand(0, args...)
	})

	AfterEach(func() {
		Expect(RemoveDockerContainer(id)).To(BeTrue())
		Expect(ExistDockerContainer(id)).NotTo(BeTrue())
		args = []string{"rmi", imageName}
		runDockerCommand(0, args...)
	})

	Describe("load with docker", func() {
		Context("load a container", func() {
			It("should load image", func() {
				file, err := ioutil.TempFile(os.TempDir(), "mynewimage.tar")
				Expect(err).ToNot(HaveOccurred())
				err = file.Close()
				Expect(err).ToNot(HaveOccurred())
				defer os.Remove(file.Name())
				Expect(file.Name()).To(BeAnExistingFile())
				imageName = "test/container-test"
				args = []string{"commit", id, imageName}
				runDockerCommand(0, args...)
				args = []string{"save", imageName, "--output", file.Name()}
				runDockerCommand(0, args...)
				args = []string{"load", "--input", file.Name()}
				stdout := runDockerCommand(0, args...)
				Expect(stdout).To(ContainSubstring(imageName))
			})
		})
	})
})
