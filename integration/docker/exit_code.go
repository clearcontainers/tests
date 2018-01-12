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
        "fmt"

        . "github.com/clearcontainers/tests"
        . "github.com/onsi/gomega"
        . "github.com/onsi/ginkgo"
        . "github.com/onsi/ginkgo/extensions/table"
)

func withExitCode(exitCode, expectedExitCode int, interactive bool) TableEntry {
        return Entry(fmt.Sprintf("with exit code '%d' when interactive mode is: '%t', it should exit '%d'",
                exitCode, interactive, expectedExitCode), exitCode, expectedExitCode, interactive)
}

var _ = Describe("docker exit code", func() {
        var (
                args             []string
                id               string
        )

        BeforeEach(func() {
                id = randomDockerName()
                args = []string{"--name", id, "--rm"}
        })

        AfterEach(func() {
                Expect(ExistDockerContainer(id)).NotTo(BeTrue())
        })

        DescribeTable("check exit codes",
                func(exitCode, expectedExitCode int, interactive bool) {
                        if interactive {
                                args = append(args, "-i")
                        }
                        args = append(args, DebianImage, "/usr/bin/perl", "-e", fmt.Sprintf("exit %d", exitCode))
                        _, _, exitCode = DockerRun(args...)
                        Expect(exitCode).To(Equal(expectedExitCode))
                },
                withExitCode(0, 0, true),
                withExitCode(0, 0, false),
                withExitCode(1, 1, true),
                withExitCode(1, 1, false),
                withExitCode(55, 55, true),
                withExitCode(55, 55, false),
                withExitCode(-1, 255, true),
                withExitCode(-1, 255, false),
                withExitCode(255, 255, true),
                withExitCode(255, 255, false),
                withExitCode(256, 0, true),
                withExitCode(256, 0, false),
        )
})
