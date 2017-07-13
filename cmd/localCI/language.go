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
	"net/http"
	"os"
	"path/filepath"
)

// Language represents a programming language
type Language interface {
	// setup the language, install, download, etc.
	setup() error

	// setup the language on a VM
	setupOnVM() error

	// getCloneDir returns the directory where the project must be cloned
	getCloneDir() string

	// getEnv returns the environment variables that must be
	// used to spawn the tests
	getEnv() []string

	// teardown the language, remove directories, unset variables, etc
	teardown() error
}

type newLanguageFunc func(Repo) (Language, error)

// RepoLanguage represents the language of a repository
type RepoLanguage struct {
	Language string
	Version  string
}

var supportedLanguages = map[string]newLanguageFunc{
	"Go": newGoLanguage,
}

var languagesDir = filepath.Join(pkgLibDir, "languages")

func init() {
	_ = os.MkdirAll(languagesDir, 0755)
}

// getLanguage returns a new object representing the repository language
func (l *RepoLanguage) getLanguage(r Repo) (Language, error) {
	if len(l.Language) == 0 {
		return nil, fmt.Errorf("missing repository language")
	}

	newLanguage, ok := supportedLanguages[l.Language]
	if !ok {
		return nil, fmt.Errorf("language '%s' is not supported", l.Language)
	}

	return newLanguage(r)
}

func download(url, dest string) error {
	out, err := os.Create(dest)
	if err != nil {
		return err
	}
	defer out.Close()

	resp, err := http.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	_, err = io.Copy(out, resp.Body)

	return err
}
