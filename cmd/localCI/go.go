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
	downloadURL string
	tarFile     string
	goRoot      string
	goPath      string
	cloneDir    string
}

var goDownloadURL = "https://storage.googleapis.com/golang"

// global lock
var goLock sync.Mutex

// newGoLanguage returns a new instance of Go
func newGoLanguage(r Repo) (Language, error) {
	goVersion := r.Language.Version

	url := fmt.Sprintf("%s/%s.linux-amd64.tar.gz", goDownloadURL, goVersion)
	tarFile := filepath.Join(languagesDir, fmt.Sprintf("%s.tar.gz", goVersion))
	goRoot := filepath.Join(languagesDir, goVersion)

	if err := os.MkdirAll(goRoot, 0755); err != nil {
		return nil, fmt.Errorf("failed to create go root directory %s", err)
	}

	goPath, err := ioutil.TempDir(pkgLibDir, "gopath")
	if err != nil {
		return nil, fmt.Errorf("failed to create go path directory %s", err)
	}

	cloneDir := filepath.Join(goPath, "src", r.cvr.getDomain(), r.cvr.getOwner())

	if err := os.MkdirAll(cloneDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create clone directory %s", err)
	}

	return &Go{
		downloadURL: url,
		tarFile:     tarFile,
		goRoot:      goRoot,
		goPath:      goPath,
		cloneDir:    cloneDir,
	}, nil
}

func (g *Go) setup() error {
	goLock.Lock()
	defer goLock.Unlock()

	// download tar if not exist
	if _, err := os.Stat(g.tarFile); os.IsNotExist(err) {
		if err = download(g.downloadURL, g.tarFile); err != nil {
			return fmt.Errorf("failed to download go compiler %s", err)
		}
	}

	goBin := filepath.Join(g.goRoot, "bin", "go")
	if _, err := os.Stat(goBin); err == nil {
		return nil
	}

	// untar
	untarCmd := exec.Command("tar", "-C", g.goRoot, "--strip-components", "1", "-xf", g.tarFile)
	if err := untarCmd.Run(); err != nil {
		return fmt.Errorf("failed to untar go compiler %s", err)
	}

	return nil
}

func (g *Go) setupOnVM() error {
	//FIXME: implement
	return nil
}

func (g *Go) getCloneDir() string {
	return g.cloneDir
}

func (g *Go) getEnv() []string {
	gobin := filepath.Join(g.goRoot, "bin")
	gopathbin := filepath.Join(g.goPath, "bin")
	path := fmt.Sprintf("%s:%s:%s", gopathbin, gobin, os.Getenv("PATH"))

	env := []string{
		fmt.Sprintf("GOROOT=%s", g.goRoot),
		fmt.Sprintf("GOPATH=%s", g.goPath),
		fmt.Sprintf("PATH=%s", path),
	}

	return env
}

func (g *Go) teardown() error {
	return os.RemoveAll(g.goPath)
}
