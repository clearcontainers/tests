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
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestNewGoLanguage(t *testing.T) {
	var err error
	var cvr CVR
	assert := assert.New(t)

	projectSlug := "github.com/clearcontainers/tests"
	url := "https://" + projectSlug
	goVersion := "go1.8.3"

	cvr, err = newCvr(url, "")
	assert.NoError(err)
	assert.NotNil(cvr)

	languagesDir, err = ioutil.TempDir("/tmp", ".languages")
	assert.NoError(err)
	defer os.RemoveAll(languagesDir)

	pkgLibDir, err = ioutil.TempDir("/tmp", ".localCI")
	assert.NoError(err)
	defer os.RemoveAll(pkgLibDir)

	// create fake tar file, to avoid download the tar
	tarPath := filepath.Join(languagesDir, fmt.Sprintf("%s.tar.gz", goVersion))
	tarFile, err := os.Create(tarPath)
	assert.NoError(err)
	assert.NoError(tarFile.Close())

	// create fake go binary
	goBinDir := filepath.Join(languagesDir, goVersion, "bin")
	assert.NoError(os.MkdirAll(goBinDir, 0755))

	goBinPath := filepath.Join(goBinDir, "go")
	goBinFile, err := os.Create(goBinPath)
	assert.NoError(err)
	assert.NoError(goBinFile.Close())

	l, err := newGoLanguage(goVersion)
	assert.NoError(err)

	goLanguage, ok := l.(*Go)
	assert.True(ok)

	assert.NotEmpty(goLanguage.goRoot)

	// check go root exists
	_, err = os.Stat(goLanguage.goRoot)
	assert.False(os.IsNotExist(err))

	langEnv, err := goLanguage.generateConfig(projectSlug)
	assert.NoError(err)
	assert.NotEmpty(langEnv.tempDir)
	assert.NotEmpty(langEnv.workingDir)
	assert.NotEmpty(langEnv.env)

	// check temp directory exist
	_, err = os.Stat(langEnv.tempDir)
	assert.False(os.IsNotExist(err))

	// check working directory exist
	_, err = os.Stat(langEnv.workingDir)
	assert.False(os.IsNotExist(err))

	// check environment
	noGopath := true
	noGoRoot := true
	noPath := true
	for _, e := range langEnv.env {
		if strings.HasPrefix(e, "GOROOT") {
			noGoRoot = false
		} else if strings.HasPrefix(e, "GOPATH") {
			noGopath = false
		} else if strings.HasPrefix(e, "PATH") {
			noPath = false
		}
	}
	assert.False(noGopath)
	assert.False(noGoRoot)
	assert.False(noPath)
}
