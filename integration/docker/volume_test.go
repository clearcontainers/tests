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

var _ = Describe("volume", func() {
	var (
		args          []string
		id            string = randomDockerName()
		id2           string = randomDockerName()
		volumeName    string = "cc3volume"
		containerPath string = "/attached_vol/"
		fileTest      string = "hello"
	)

	Describe("volume with docker", func() {
		Context("create volume", func() {
			It("should display the volume's name", func() {
				args = []string{"volume", "create", "--name", volumeName}
				runDockerCommand(0, args...)
				args = []string{"volume", "inspect", volumeName}
				runDockerCommand(0, args...)
				args = []string{"volume", "rm", volumeName}
				runDockerCommand(0, args...)
				args = []string{"volume", "ls"}
				stdout := runDockerCommand(0, args...)
				Expect(stdout).NotTo(ContainSubstring(volumeName))
			})
		})

		Context("use volume in a container", func() {
			It("should display the volume", func() {
				args = []string{"run", "--name", id, "-t", "-v", volumeName + ":" + containerPath, Image, "touch", containerPath + fileTest}
				runDockerCommand(0, args...)
				args = []string{"run", "--name", id2, "-t", "-v", volumeName + ":" + containerPath, Image, "ls", containerPath}
				stdout := runDockerCommand(0, args...)
				Expect(stdout).To(ContainSubstring(fileTest))
				Expect(ContainerRemove(id)).To(BeTrue())
				Expect(ContainerExists(id)).NotTo(BeTrue())
				Expect(ContainerRemove(id2)).To(BeTrue())
				Expect(ContainerExists(id2)).NotTo(BeTrue())
				args = []string{"volume", "rm", volumeName}
				runDockerCommand(0, args...)
				args = []string{"volume", "ls"}
				stdout = runDockerCommand(0, args...)
				Expect(stdout).NotTo(ContainSubstring(volumeName))
			})
		})

		Context("volume bind-mount a directory", func() {
			It("should display directory's name", func() {
				file, err := ioutil.TempFile(os.TempDir(), fileTest)
				Expect(err).ToNot(HaveOccurred())
				err = file.Close()
				Expect(err).ToNot(HaveOccurred())
				defer os.Remove(file.Name())
				Expect(file.Name()).To(BeAnExistingFile())
				testFile := path.Base(file.Name())
				args = []string{"run", "--name", id, "-v", testFile + ":/root/" + fileTest, Image, "ls", "/root/"}
				stdout := runDockerCommand(0, args...)
				Expect(stdout).To(ContainSubstring(fileTest))
				Expect(ContainerRemove(id)).To(BeTrue())
				Expect(ContainerExists(id)).NotTo(BeTrue())
				args = []string{"volume", "rm", testFile}
				runDockerCommand(0, args...)
				args = []string{"volume", "ls"}
				stdout = runDockerCommand(0, args...)
				Expect(stdout).NotTo(ContainSubstring(testFile))
			})
		})
	})
})
