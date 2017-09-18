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
	"syscall"
	"time"

	. "github.com/clearcontainers/tests"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/ginkgo/extensions/table"
	. "github.com/onsi/gomega"
)

const (
	canBeTrapped    = true
	cannotBeTrapped = false
)

func withSignal(signal syscall.Signal, trap bool) TableEntry {
	expectedExitCode := int(signal)
	if !trap {
		// 128 -> command interrupted by a signal
		expectedExitCode += 128
	}

	return Entry(fmt.Sprintf("with '%d' signal", signal), signal, expectedExitCode)
}

func withoutSignal() TableEntry {
	// 137 = 128(command interrupted by a signal) + 9(SIGKILL)
	return Entry(fmt.Sprintf("without a signal"), syscall.Signal(0), 137)
}

func withSignalNotExitCode(signal syscall.Signal) TableEntry {
	return Entry(fmt.Sprintf("with '%d' signal, don't change the exit code", signal), signal, 0)
}

var _ = Describe("docker kill", func() {
	var (
		args []string
		id   string
	)

	BeforeEach(func() {
		id = randomDockerName()
	})

	AfterEach(func() {
		Expect(RemoveDockerContainer(id)).To(BeTrue())
		Expect(ExistDockerContainer(id)).NotTo(BeTrue())
	})

	DescribeTable("killing container",
		func(signal syscall.Signal, expectedExitCode int) {
			args = []string{"--name", id, "-dt", Image, "sh", "-c"}

			if signal > 0 {
				args = append(args, fmt.Sprintf("trap \"exit %d\" %d ; while : ; do sleep 1; done", signal, signal))
			} else {
				args = append(args, fmt.Sprintf("while : ; do sleep 1; done"))
			}

			DockerRun(args...)

			// we have to wait for the container workload
			// to process the trap.
			time.Sleep(5 * time.Second)
			
			if signal > 0 {
				DockerKill("-s", fmt.Sprintf("%d", signal), id)
			} else {
				DockerKill(id)
			}

			// we have to wait for signal processing (trap)
			// this is needed even with runc
			time.Sleep(5 * time.Second)

			exitCode, err := ExitCodeDockerContainer(id)
			Expect(err).ToNot(HaveOccurred())
			Expect(exitCode).To(Equal(expectedExitCode))
		},
		withSignal(syscall.SIGHUP, canBeTrapped),
		withSignal(syscall.SIGINT, canBeTrapped),
		withSignal(syscall.SIGQUIT, cannotBeTrapped), //131
		withSignal(syscall.SIGILL, cannotBeTrapped),  //132
		withSignal(syscall.SIGTRAP, canBeTrapped),
		withSignal(syscall.SIGIOT, canBeTrapped),
		withSignal(syscall.SIGBUS, cannotBeTrapped),  //135
		withSignal(syscall.SIGFPE, cannotBeTrapped),  //136
		withSignal(syscall.SIGKILL, cannotBeTrapped), //137
		withSignal(syscall.SIGUSR1, canBeTrapped),
		withSignal(syscall.SIGSEGV, cannotBeTrapped), //139
		withSignal(syscall.SIGUSR2, canBeTrapped),
		withSignal(syscall.SIGPIPE, cannotBeTrapped), //141
		withSignal(syscall.SIGALRM, canBeTrapped),
		withSignal(syscall.SIGTERM, canBeTrapped),
		withSignal(syscall.SIGSTKFLT, canBeTrapped),
		withSignal(syscall.SIGCHLD, canBeTrapped),
		withSignal(syscall.SIGCONT, canBeTrapped),
		withSignalNotExitCode(syscall.SIGSTOP), //0 - don't change exit code
		withSignal(syscall.SIGTSTP, canBeTrapped),
		withSignal(syscall.SIGTTIN, canBeTrapped),
		withSignal(syscall.SIGTTOU, canBeTrapped),
		withSignal(syscall.SIGURG, canBeTrapped),
		withSignal(syscall.SIGXCPU, canBeTrapped),
		withSignal(syscall.SIGXFSZ, canBeTrapped),
		withSignal(syscall.SIGVTALRM, canBeTrapped),
		withSignal(syscall.SIGPROF, canBeTrapped),
		withSignalNotExitCode(syscall.SIGWINCH), //0 - don't change exit code
		withSignal(syscall.SIGIO, canBeTrapped),
		withSignal(syscall.SIGPWR, canBeTrapped),
		withoutSignal(),
	)
})
