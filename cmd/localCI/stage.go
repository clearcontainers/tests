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
	"os"
	"os/exec"
	"path/filepath"

	"github.com/Sirupsen/logrus"
)

type stageConfig struct {
	logDir     string
	env        []string
	workingDir string
	logger     *logrus.Entry
}

type stage struct {
	name     string
	commands []string
}

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

	for _, c := range s.commands {
		cmd := exec.Command("bash", "-c", c)
		cmd.Stdout = output
		cmd.Stderr = output
		cmd.Env = config.env
		cmd.Dir = config.workingDir

		if err := cmd.Run(); err != nil {
			config.logger.Debugf("failed to run command: %+v", cmd)
			return err
		}
	}

	return nil
}
