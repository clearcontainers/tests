// Copyright (c) 2018 Intel Corporation
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

var _ = Describe("docker privileges", func() {
	var (
		args		[]string
		id		string
		secondId	string
		testImage	string
		exitCode	int
	)

	BeforeEach(func() {
		id = randomDockerName()
		secondId = randomDockerName()
		testImage = "testprivileges"
	})


	AfterEach(func() {
		Expect(RemoveDockerContainer(id)).To(BeTrue())
		Expect(ExistDockerContainer(id)).NotTo(BeTrue())
		_, _, exitCode := DockerRmi(testImage)
		Expect(exitCode).To(Equal(0))
	})

	Context("check no-new-privileges flag", func() {
		It("should display the correct uid", func() {
			args = []string{"-d", "--name", id, FedoraImage, "sh", "-c", "chmod -s /usr/bin/id"}
			_, _, exitCode = DockerRun(args...)
			Expect(exitCode).To(Equal(0))

			file, err := ioutil.TempFile(os.TempDir(), "latest.tar")
			Expect(err).ToNot(HaveOccurred())
			_, _, exitCode := DockerExport("--output", file.Name(), id)
			Expect(exitCode).To(Equal(0))
			Expect(file.Name()).To(BeAnExistingFile())

			_, _, exitCode = DockerImport(file.Name(), testImage)
			Expect(exitCode).To(Equal(0))
			defer os.Remove(file.Name())

			args = []string{"--rm", "--name", secondId, "--user", "1000", "--security-opt=no-new-privileges", testImage, "/usr/bin/id"}
			stdout, _, exitCode := DockerRun(args...)
			Expect(exitCode).To(Equal(0))
			Expect(stdout).NotTo(ContainSubstring("euid=0(root)"))
			Expect(stdout).To(ContainSubstring("uid=1000"))
		})
	})
})
