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

func withWorkload(workload string, expectedExitCode int) TableEntry {
	return Entry(fmt.Sprintf("with '%v' as workload", workload), workload, expectedExitCode)
}

var _ = Describe("run", func() {
	var (
		args []string
		id   string
	)

	BeforeEach(func() {
		id = RandID(30)
		args = []string{"run", "--rm", "--name", id, Image, "sh", "-c"}
	})

	AfterEach(func() {
		Expect(ContainerExists(id)).NotTo(BeTrue())
	})

	DescribeTable("container with docker",
		func(workload string, expectedExitCode int) {
			args = append(args, workload)

			command := NewCommand(Docker, args...)
			Expect(command).NotTo(BeNil())

			exitCode := command.Run()
			LogIfFail(command.Stderr.String())

			Expect(expectedExitCode).To(Equal(exitCode))
		},
		withWorkload("true", 0),
		withWorkload("false", 1),
		withWorkload("exit 0", 0),
		withWorkload("exit 1", 1),
		withWorkload("exit 15", 15),
		withWorkload("exit 123", 123),
	)
})

var _ = Describe("run", func() {
	var (
		args []string
		id   string
	)

	BeforeEach(func() {
		id = RandID(30)
		args = []string{"run", "--name", id}
	})

	AfterEach(func() {
		Expect(ContainerRemove(id)).To(BeTrue())
		Expect(ContainerExists(id)).NotTo(BeTrue())
	})

	DescribeTable("container with docker",
		func(options, expectedStatus string) {
			args = append(args, options, Image, "sh")

			command := NewCommand(Docker, args...)
			Expect(command).NotTo(BeNil())

			exitCode := command.Run()
			LogIfFail(command.Stderr.String())

			Expect(exitCode).To(BeZero())

			Expect(ContainerStatus(id)).To(Equal(expectedStatus))

			Expect(ContainerExists(id)).To(BeTrue())
		},
		Entry("in background and interactive", "-di", "Up"),
		Entry("in background, interactive and with a tty", "-dit", "Up"),
	)
})
