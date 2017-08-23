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

var _ = Describe("export", func() {
	var (
		id string
	)

	BeforeEach(func() {
		id = randomDockerName()
		_, _, exitCode := DockerRun("-td", "--name", id, Image)
		Expect(exitCode).To(Equal(0))
	})

	AfterEach(func() {
		Expect(RemoveDockerContainer(id)).To(BeTrue())
		Expect(ExistDockerContainer(id)).NotTo(BeTrue())
	})

	Describe("export with docker", func() {
		Context("export a container", func() {
			It("should export filesystem as a tar archive", func() {
				file, err := ioutil.TempFile(os.TempDir(), "latest.tar")
				Expect(err).ToNot(HaveOccurred())
				defer os.Remove(file.Name())
				_, _, exitCode := DockerExport("--output", file.Name(), id)
				Expect(exitCode).To(Equal(0))
				Expect(file.Name()).To(BeAnExistingFile())
				fileInfo, err := file.Stat()
				Expect(err).ToNot(HaveOccurred())
				Expect(fileInfo.Size).NotTo(Equal(0))
				err = file.Close()
				Expect(err).ToNot(HaveOccurred())
			})
		})
	})
})
