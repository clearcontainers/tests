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
		// http://www.tldp.org/LDP/abs/html/exitcodes.html
		expectedExitCode += 128
	}

	return Entry(fmt.Sprintf("with '%d'(%s) signal", signal, syscall.Signal(signal)), signal, expectedExitCode)
}

func withoutSignal() TableEntry {
	// 137 = 128(command interrupted by a signal) + 9(SIGKILL)
	return Entry(fmt.Sprintf("without a signal"), syscall.Signal(0), 137)
}

func withSignalNotExitCode(signal syscall.Signal) TableEntry {
	return Entry(fmt.Sprintf("with '%d' (%s) signal, don't change the exit code", signal, signal), signal, 0)
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

			switch signal {
			case syscall.SIGQUIT, syscall.SIGILL, syscall.SIGBUS, syscall.SIGFPE, syscall.SIGSEGV, syscall.SIGPIPE:
				Skip("This is not forwarded by cc-shim " +
					"https://github.com/clearcontainers/runtime/issues/769")
			case syscall.SIGWINCH:
				Skip("Signal is not being forwared,  see " +
					"https://github.com/clearcontainers/runtime/issues/768")
			}

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
		withSignal(syscall.SIGQUIT, canBeTrapped),
		withSignal(syscall.SIGILL, canBeTrapped),
		withSignal(syscall.SIGTRAP, canBeTrapped),
		withSignal(syscall.SIGIOT, canBeTrapped),
		withSignal(syscall.SIGFPE, canBeTrapped),
		withSignal(syscall.SIGKILL, cannotBeTrapped), //137
		withSignal(syscall.SIGUSR1, canBeTrapped),
		withSignal(syscall.SIGSEGV, canBeTrapped),
		withSignal(syscall.SIGUSR2, canBeTrapped),
		withSignal(syscall.SIGPIPE, canBeTrapped),
		withSignal(syscall.SIGALRM, canBeTrapped),
		withSignal(syscall.SIGTERM, canBeTrapped),
		withSignal(syscall.SIGSTKFLT, canBeTrapped),
		withSignal(syscall.SIGCHLD, canBeTrapped),
		withSignal(syscall.SIGCONT, canBeTrapped),
		withSignalNotExitCode(syscall.SIGSTOP),
		withSignal(syscall.SIGTSTP, canBeTrapped),
		withSignal(syscall.SIGTTIN, canBeTrapped),
		withSignal(syscall.SIGTTOU, canBeTrapped),
		withSignal(syscall.SIGURG, canBeTrapped),
		withSignal(syscall.SIGXCPU, canBeTrapped),
		withSignal(syscall.SIGXFSZ, canBeTrapped),
		withSignal(syscall.SIGVTALRM, canBeTrapped),
		withSignal(syscall.SIGPROF, canBeTrapped),
		withSignal(syscall.SIGWINCH, canBeTrapped),
		withSignal(syscall.SIGIO, canBeTrapped),
		withSignal(syscall.SIGPWR, canBeTrapped),
		withoutSignal(),
	)
})
