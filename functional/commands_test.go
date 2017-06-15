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

package functional

import (
	"fmt"

	. "github.com/clearcontainers/tests"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/ginkgo/extensions/table"
	. "github.com/onsi/gomega"
)

func withoutID(command string) TableEntry {
	cmd := NewCommand(Runtime, command)
	return Entry(fmt.Sprintf("command '%s'", command), cmd)
}

func withInexistentID(command string) TableEntry {
	cmd := NewCommand(Runtime, command, RandID(30))
	return Entry(fmt.Sprintf("command '%s'", command), cmd)
}

var _ = Describe("commands", func() {
	var exitCode int

	DescribeTable("without a container ID should fail",
		func(cmd *Command) {
			exitCode = cmd.Run()

			Ω(exitCode).ShouldNot(Equal(0))
			Ω(cmd.Stderr.String()).ShouldNot(BeEmpty())
		},
		withoutID("kill"),
		withoutID("delete"),
		withoutID("start"),
		withoutID("state"),
	)

	DescribeTable("with a inexistent container ID should fail",
		func(cmd *Command) {
			exitCode = cmd.Run()

			Ω(exitCode).ShouldNot(Equal(0))
			Ω(cmd.Stderr.String()).ShouldNot(BeEmpty())
		},
		withInexistentID("kill"),
		withInexistentID("delete"),
		withInexistentID("start"),
		withInexistentID("state"),
	)
})
