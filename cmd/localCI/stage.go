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

package main

import (
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
	"syscall"

	"github.com/Sirupsen/logrus"
)

type stageConfig struct {
	logDir     string
	env        []string
	workingDir string
	logger     *logrus.Entry
	tty        bool
}

type stage struct {
	name     string
	commands []string
}

const consoleFileMode = os.FileMode(0660)

func (s *stage) run(config stageConfig) error {
	config.logger.Debugf("running stage: %+v", *s)

	if len(s.commands) == 0 {
		return fmt.Errorf("there are not commands for the stage '%s'", s.name)
	}

	outFile := filepath.Join(config.logDir, s.name)
	output, err := os.OpenFile(outFile, os.O_WRONLY|os.O_APPEND|os.O_CREATE, logFileMode)
	if err != nil {
		return err
	}
	defer output.Close()

	if config.tty {
		return s.runTTY(config, output)
	}

	// run stage commands
	for _, c := range s.commands {
		cmd := exec.Command("bash", "-c", c)
		cmd.Stdout = output
		cmd.Stderr = output
		cmd.Env = config.env
		cmd.Dir = config.workingDir

		if err := cmd.Run(); err != nil {
			config.logger.Debugf("failed to run command: %+v", cmd)
			return fmt.Errorf("failed to run command %+v in stage %s: %s", cmd.Args, s.name, err)
		}
	}

	return nil
}

// runTTY run the stage allocating a new TTY
func (s *stage) runTTY(config stageConfig, output *os.File) error {
	var wg sync.WaitGroup

	// allocate a new console (master)
	console, err := newConsole()
	if err != nil {
		return fmt.Errorf("failed to allocate a new console in stage %s %s", s.name, err)
	}

	// open tty (slave)
	tty, err := os.OpenFile(console.Path(), os.O_RDWR, consoleFileMode)
	if err != nil {
		_ = console.Close()
		return fmt.Errorf("failed to open slave tty in stage %s %s", s.name, err)
	}

	// dup tty's output
	wg.Add(1)
	go func() {
		defer wg.Done()
		io.Copy(output, console)
	}()

	defer func() {
		// close tty (slave)
		if err := tty.Close(); err != nil {
			config.logger.Warnf("failed to close slave tty in stage %s: %s", s.name, err)
		}

		// close console (master)
		if err := console.Close(); err != nil {
			config.logger.Warnf("failed to close console in stage %s: %s", s.name, err)
		}

		// wait for io.Copy
		wg.Wait()
	}()

	for _, c := range s.commands {
		cmd := exec.Command("bash", "-c", c)
		cmd.Stdout = tty
		cmd.Stderr = tty
		cmd.Stdin = tty
		cmd.Env = config.env
		cmd.Dir = config.workingDir

		cmd.SysProcAttr = &syscall.SysProcAttr{
			// create session
			Setsid: true,

			// set controlling terminal to ctty
			Setctty: true,
			Ctty:    int(tty.Fd()),
		}

		if err := cmd.Run(); err != nil {
			config.logger.Debugf("failed to run command: %+v", cmd)
			return fmt.Errorf("failed to run command %+v in stage %s: %s", cmd.Args, s.name, err)
		}
	}

	return nil
}
