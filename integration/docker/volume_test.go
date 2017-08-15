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

var _ = Describe("docker volume", func() {
	var (
		args          []string
		id            string = randomDockerName()
		id2           string = randomDockerName()
		volumeName    string = "cc3volume"
		containerPath string = "/attached_vol/"
		fileTest      string = "hello"
		exitCode      int
		stdout        string
	)

	Context("create volume", func() {
		It("should display the volume's name", func() {
			_, _, exitCode = DockerVolume("create", "--name", volumeName)
			Expect(exitCode).To(Equal(0))
			_, _, exitCode = DockerVolume("inspect", volumeName)
			Expect(exitCode).To(Equal(0))
			_, _, exitCode = DockerVolume("rm", volumeName)
			Expect(exitCode).To(Equal(0))
			stdout, _, exitCode = DockerVolume("ls")
			Expect(exitCode).To(Equal(0))
			Expect(stdout).NotTo(ContainSubstring(volumeName))
		})
	})

	Context("use volume in a container", func() {
		It("should display the volume", func() {
			args = []string{"--name", id, "-t", "-v", volumeName + ":" + containerPath, Image, "touch", containerPath + fileTest}
			_, _, exitCode = DockerRun(args...)
			Expect(exitCode).To(Equal(0))

			args = []string{"--name", id2, "-t", "-v", volumeName + ":" + containerPath, Image, "ls", containerPath}
			stdout, _, exitCode = DockerRun(args...)
			Expect(exitCode).To(Equal(0))
			Expect(stdout).To(ContainSubstring(fileTest))

			Expect(RemoveDockerContainer(id)).To(BeTrue())
			Expect(ExistDockerContainer(id)).NotTo(BeTrue())
			Expect(RemoveDockerContainer(id2)).To(BeTrue())
			Expect(ExistDockerContainer(id2)).NotTo(BeTrue())

			_, _, exitCode = DockerVolume("rm", volumeName)
			Expect(exitCode).To(Equal(0))

			stdout, _, exitCode = DockerVolume("ls")
			Expect(exitCode).To(Equal(0))
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
			args = []string{"--name", id, "-v", testFile + ":/root/" + fileTest, Image, "ls", "/root/"}
			stdout, _, exitCode = DockerRun(args...)
			Expect(exitCode).To(Equal(0))
			Expect(stdout).To(ContainSubstring(fileTest))

			Expect(RemoveDockerContainer(id)).To(BeTrue())
			Expect(ExistDockerContainer(id)).NotTo(BeTrue())

			_, _, exitCode = DockerVolume("rm", testFile)
			Expect(exitCode).To(Equal(0))

			stdout, _, exitCode = DockerVolume("ls")
			Expect(exitCode).To(Equal(0))
			Expect(stdout).NotTo(ContainSubstring(testFile))
		})
	})
})
