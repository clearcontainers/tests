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
	"io/ioutil"
	"os"
	"os/exec"
	"path/filepath"
)

const (
	sshDirMode  = 0700
	sshFileMode = 0600
)

// LogServer represents the server where the logs are copied
type LogServer struct {
	IP   string
	User string
	Dir  string
	Key  string
}

// copy path to the log server
func (l *LogServer) copy(path string) error {
	cmd := []string{"-r", "-o", "UserKnownHostsFile=/dev/null", "-o", "StrictHostKeyChecking=no"}

	if len(l.Key) > 0 {
		sshDir, err := ioutil.TempDir(pkgLibDir, ".ssh")
		if err != nil {
			return err
		}
		defer os.RemoveAll(sshDir)

		err = os.Chmod(sshDir, sshDirMode)
		if err != nil {
			return err
		}

		sshFile := filepath.Join(sshDir, "key")
		err = ioutil.WriteFile(sshFile, []byte(l.Key), sshFileMode)
		if err != nil {
			return err
		}

		// append ssh key
		cmd = append(cmd, "-i", sshFile)
	}

	// append path to copy
	cmd = append(cmd, path)

	//append user, ip and destination
	cmd = append(cmd, fmt.Sprintf("%s@%s:%s", l.User, l.IP, l.Dir))

	ciLog.Debugf("log server copy command: scp %+v", cmd)

	command := exec.Command("scp", cmd...)
	return command.Run()
}
