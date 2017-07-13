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

	url := "https://github.com/clearcontainers/tests"

	cvr, err = newCvr(url, "")
	assert.NoError(err)
	assert.NotNil(cvr)

	languagesDir, err = ioutil.TempDir("/tmp", ".languages")
	assert.NoError(err)
	defer os.RemoveAll(languagesDir)

	pkgLibDir, err = ioutil.TempDir("/tmp", ".localCI")
	assert.NoError(err)
	defer os.RemoveAll(pkgLibDir)

	r := Repo{
		Language: RepoLanguage{
			Language: "Go",
			Version:  "go1.8.3",
		},
		cvr: cvr,
	}

	l, err := newGoLanguage(r)
	assert.NoError(err)

	goLanguage, ok := l.(*Go)
	assert.True(ok)

	assert.NotEmpty(goLanguage.downloadURL)
	assert.NotEmpty(goLanguage.tarFile)
	assert.NotEmpty(goLanguage.goRoot)
	assert.NotEmpty(goLanguage.goPath)
	assert.NotEmpty(goLanguage.cloneDir)

	// check go root exists
	_, err = os.Stat(goLanguage.goRoot)
	assert.False(os.IsNotExist(err))

	// check go path exists
	_, err = os.Stat(goLanguage.goPath)
	assert.False(os.IsNotExist(err))

	// check clone directory
	cloneDir := filepath.Join(goLanguage.goPath, "src/github.com/clearcontainers")
	assert.Equal(goLanguage.getCloneDir(), cloneDir)

	// check environment
	noGopath := true
	noGoRoot := true
	for _, e := range goLanguage.getEnv() {
		if strings.HasPrefix(e, "GOROOT") {
			noGoRoot = false
		} else if strings.HasPrefix(e, "GOPATH") {
			noGopath = false
		}
	}
	assert.False(noGopath)
	assert.False(noGoRoot)
}
