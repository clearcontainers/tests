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
	"sync"
)

// Go programming language
type Go struct {
	goRoot string
}

var goDownloadURL = "https://storage.googleapis.com/golang"

// global lock
var goLock sync.Mutex

// newGoLanguage returns a new instance of Go
func newGoLanguage(goVersion string) (language, error) {
	// setup GOROOT
	goRoot := filepath.Join(languagesDir, goVersion)
	if err := os.MkdirAll(goRoot, 0755); err != nil {
		return nil, fmt.Errorf("failed to create go root directory %s", err)
	}

	goLock.Lock()
	defer goLock.Unlock()

	// download tar if not exist
	url := fmt.Sprintf("%s/%s.linux-amd64.tar.gz", goDownloadURL, goVersion)
	tarFile := filepath.Join(languagesDir, fmt.Sprintf("%s.tar.gz", goVersion))

	if _, err := os.Stat(tarFile); os.IsNotExist(err) {
		if err = downloadFile(url, tarFile); err != nil {
			return nil, fmt.Errorf("failed to download go compiler %s", err)
		}
	}

	// untar go.tar if go binary does not exist
	goBin := filepath.Join(goRoot, "bin", "go")
	if _, err := os.Stat(goBin); os.IsNotExist(err) {
		untarCmd := exec.Command("tar", "-C", goRoot, "--strip-components", "1", "-xf", tarFile)
		if err := untarCmd.Run(); err != nil {
			return nil, fmt.Errorf("failed to untar go compiler %s", err)
		}
	}

	return &Go{
		goRoot: goRoot,
	}, nil
}

func (g *Go) generateConfig(projectSlug string) (languageConfig, error) {
	l := languageConfig{}

	// setup GOPATH
	goPath, err := ioutil.TempDir(languagesDir, "gopath")
	if err != nil {
		return l, fmt.Errorf("failed to create go path directory %s", err)
	}

	gobin := filepath.Join(g.goRoot, "bin")
	gopathbin := filepath.Join(goPath, "bin")
	path := fmt.Sprintf("%s:%s:%s", gopathbin, gobin, os.Getenv("PATH"))

	env := []string{
		fmt.Sprintf("GOROOT=%s", g.goRoot),
		fmt.Sprintf("GOPATH=%s", goPath),
		fmt.Sprintf("PATH=%s", path),
	}

	workingDir := filepath.Join(goPath, "src", projectSlug)
	err = os.MkdirAll(workingDir, logDirMode)
	if err != nil {
		return l, err
	}

	return languageConfig{
		tempDir:    goPath,
		workingDir: workingDir,
		env:        env,
	}, nil
}
