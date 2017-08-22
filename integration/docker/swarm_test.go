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

var _ = Describe("swarm", func() {
	var (
		args           []string
		stdout         string
		exitCode       int
		numberReplicas string = "1"
		swarmImage     string = "gabyct/nginx"
		serviceName    string = "test"
		portNumber     string = "8080:80"
	)

	BeforeEach(func() {
		Skip("Issue https://github.com/clearcontainers/runtime/issues/443")
		_, _, exitCode = DockerSwarm("init")
		Expect(exitCode).To(Equal(0))
		nginxCommand := `"hostname > /usr/share/nginx/html/hostname; nginx -g \"daemon off;\""`
		args = []string{"create", "--name", serviceName, "--replicas", numberReplicas, "--detach=true", "--publish", portNumber, swarmImage, "sh", "-c", nginxCommand}
		_, _, exitCode = DockerService(args...)
		Expect(exitCode).To(Equal(0))
		args = []string{"inspect", "--format='{{.Spec.Mode.Replicated.Replicas}}'", serviceName}
		stdout, _, exitCode = DockerService(args...)
		Expect(exitCode).To(Equal(0))
		Expect(stdout).To(ContainSubstring(numberReplicas))
	})

	AfterEach(func() {
		_, _, exitCode = DockerSwarm("leave", "--force")
		Expect(exitCode).To(Equal(0))
	})

	Context("check interfaces with docker swarm", func() {
		It("should retrieve two interfaces", func() {
			replicaId, _, exitCode := DockerPs("-aq")
			Expect(exitCode).To(Equal(0))
			execCommand := "ip route show | grep -E eth0 && ip route show | grep -E eth1"
			args = []string{replicaId, "sh", "-c", execCommand}
			stdout, _, exitCode = DockerExec(args...)
			Expect(exitCode).To(Equal(0))
			Expect(stdout).To(ContainSubstring("eth1"))
			Expect(stdout).To(ContainSubstring("eth0"))
		})
	})
})
