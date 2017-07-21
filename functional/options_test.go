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

func withOption(option string, fail bool) TableEntry {
	command := NewCommand(Runtime, option)
	return Entry(fmt.Sprintf("with option '%s'", option), command, fail)
}

var _ = Describe("global options", func() {
	DescribeTable("option",
		func(command *Command, fail bool) {
			exitCode := command.Run()

			if fail {
				Expect(exitCode).NotTo(Equal(0))
				Expect(command.Stderr.String()).NotTo(BeEmpty())
				Expect(command.Stdout.String()).NotTo(BeEmpty())
			} else {
				Expect(exitCode).To(Equal(0))
				Expect(command.Stderr.String()).To(BeEmpty())
				Expect(command.Stdout.String()).NotTo(BeEmpty())
			}
		},
		withOption("--version", shouldNotFail),
		withOption("--v", shouldNotFail),
		withOption("--help", shouldNotFail),
		withOption("--h", shouldNotFail),
		withOption("--this-option-does-not-exist", shouldFail),
	)
})
