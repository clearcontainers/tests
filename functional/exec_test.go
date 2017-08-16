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
	"time"

	. "github.com/clearcontainers/tests"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/ginkgo/extensions/table"
	. "github.com/onsi/gomega"
)

var sleepingContainerWorkload = []string{"sh", "-c", "sleep 1000"}

func execDetachTiming(detach bool) TableEntry {
	comparator := ">="
	if detach {
		comparator = "<"
	}

	timeout := 1

	process := Process{
		Workload: []string{"sleep", fmt.Sprintf("%d", timeout)},
		Detach:   detach,
	}

	return Entry(fmt.Sprintf("check time as detach=%t", detach), process, comparator, timeout)
}

func execDetachOutput(detach bool) TableEntry {
	output := "HelloWorld"

	process := Process{
		Workload: []string{"echo", output},
		Detach:   detach,
	}

	expectedOutput := output
	if detach {
		expectedOutput = ""
	}

	return Entry(fmt.Sprintf("check output as detach=%t", detach), process, expectedOutput)
}

var _ = Describe("exec", func() {
	var (
		container *Container
		exitCode  int
		err       error
	)

	BeforeEach(func() {
		container, err = NewContainer(sleepingContainerWorkload, true)
		Expect(err).NotTo(HaveOccurred())
		Expect(container).NotTo(BeNil())
		_, _, exitCode := container.Run()
		Expect(exitCode).Should(Equal(0))
	})

	AfterEach(func() {
		Expect(container.Exist()).Should(BeTrue())
		_, _, exitCode = container.Delete(true)
		Expect(exitCode).Should(Equal(0))
		Expect(container.Cleanup()).Should(Succeed())
	})

	DescribeTable("container",
		func(process Process, comparator string, timeout int) {
			process.ContainerID = container.ID
			tInit := time.Now()

			_, _, exitCode = container.Exec(process)
			Expect(exitCode).Should(Equal(0))

			duration := time.Since(tInit)
			Expect(duration.Seconds()).Should(BeNumerically(comparator, timeout))
		},
		execDetachTiming(false),
		execDetachTiming(true),
	)

	DescribeTable("container",
		func(process Process, expectedOutput string) {
			process.ContainerID = container.ID

			stdout, stderr, exitCode := container.Exec(process)
			Expect(exitCode).Should(Equal(0))

			if expectedOutput != "" {
				Expect(stdout).Should(ContainSubstring(expectedOutput))
			} else {
				Expect(stdout).Should(BeEmpty())
			}

			Expect(stderr).Should(BeEmpty())
		},
		execDetachOutput(false),
		execDetachOutput(true),
	)
})
