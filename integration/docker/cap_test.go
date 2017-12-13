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
	"fmt"

	. "github.com/clearcontainers/tests"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/ginkgo/extensions/table"
	. "github.com/onsi/gomega"
)

func selectCaps(selectOption string) TableEntry {
	return Entry(fmt.Sprintf("cap_%s", selectOption), selectOption)
}

var _ = Describe("capabilities", func() {
	var (
		args		[]string
		id		string
		anotherId	string
		stdout		string
		exitCode	int
	)

	BeforeEach(func() {
		id = randomDockerName()
		anotherId = randomDockerName()
	})

	AfterEach(func() {
		Expect(ExistDockerContainer(id)).NotTo(BeTrue())
		Expect(ExistDockerContainer(anotherId)).NotTo(BeTrue())
	})

	DescribeTable("drop and add capabilities",
		func(selectOption string) {
			Skip("Issue https://github.com/clearcontainers/agent/issues/181")
			args = []string{"--name", id, "--rm", "--cap-drop", selectOption, FedoraImage, "capsh --print"}
			stdout, _, exitCode = DockerRun(args...)
			Expect(exitCode).To(Equal(0))
			Expect(stdout).NotTo(ContainSubstring("cap_"+selectOption))

			args = []string{"--name", anotherId, "--rm", "--cap-add", selectOption, FedoraImage, "capsh --print"}
			stdout, _, exitCode = DockerRun(args...)
			Expect(exitCode).To(Equal(0))
			Expect(stdout).To(ContainSubstring("cap_"+selectOption))
		},
		selectCaps("audit_control"),
		selectCaps("audit_read"),
		selectCaps("audit_write"),
		selectCaps("block_suspend"),
		selectCaps("chown"),
		selectCaps("dac_override"),
		selectCaps("dac_read_search"),
		selectCaps("fowner"),
		selectCaps("fsetid"),
		selectCaps("ipc_lock"),
		selectCaps("ipc_owner"),
		selectCaps("kill"),
		selectCaps("lease"),
		selectCaps("linux_immutable"),
		selectCaps("mac_admin"),
		selectCaps("mac_override"),
		selectCaps("mknod"),
		selectCaps("net_admin"),
		selectCaps("net_bind_service"),
		selectCaps("net_broadcast"),
		selectCaps("net_raw"),
		selectCaps("setgid"),
		selectCaps("setfcap"),
		selectCaps("setuid"),
		selectCaps("setpcap"),
		selectCaps("sys_admin"),
		selectCaps("sys_boot"),
		selectCaps("sys_chroot"),
		selectCaps("sys_nice"),
		selectCaps("sys_pacct"),
		selectCaps("sys_rawio"),
		selectCaps("sys_resource"),
		selectCaps("sys_time"),
		selectCaps("syslog"),
		selectCaps("wake_alarm"),
	)
})
