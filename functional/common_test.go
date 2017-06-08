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
	"math/rand"

	. "github.com/clearcontainers/tests"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

const letters = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"

const lettersMask = 63

func randString(n int) string {
	b := make([]byte, n)
	for i := 0; i < n; {
		if j := int(rand.Int63() & lettersMask); j < len(letters) {
			b[i] = letters[j]
			i++
		}
	}

	return string(b)
}

// DescribeCommandWithoutID describes a command without a container ID
func DescribeCommandWithoutID(command string) bool {
	return Describe(command, func() {
		expectExitCode := 1
		c := NewCommand(Runtime, command)
		ret := c.Run()
		Context("without container id", func() {
			It(fmt.Sprintf("should return '%d'", expectExitCode), func() {
				Expect(expectExitCode).To(Equal(ret))
			})
			It("should report an error", func() {
				Expect(c.Stderr.Len()).NotTo(Equal(0))
			})
		})
	})
}

// DescribeCommandWithInexistentID describes a command with an inexistent container ID
func DescribeCommandWithInexistentID(command string) bool {
	return Describe(command, func() {
		expectExitCode := 1
		c := NewCommand(Runtime, command, randString(30))
		ret := c.Run()
		Context("with inexistent container id", func() {
			It(fmt.Sprintf("should return '%d'", expectExitCode), func() {
				Expect(expectExitCode).To(Equal(ret))
			})
			It("should report an error", func() {
				Expect(c.Stderr.Len()).NotTo(Equal(0))
			})
		})
	})
}
