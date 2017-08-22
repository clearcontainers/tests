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

// language represents a programming language
type language interface {
	// generateConfig generates a unique working directory.
	// Returns a languageConfig that must be used to test
	// the project.
	// projectSlug must contain the cvr domain, owner and repo name
	// separated by '/'. i.e github.com/clearcontainers/tests
	generateConfig(projectSlug string) (languageConfig, error)
}

type newLanguageFunc func(version string) (language, error)

// RepoLanguage represents the language of a repository
type RepoLanguage struct {
	Language string
	Version  string
	lang     language
}

// languageConfig to test the project
type languageConfig struct {
	// temporal directory created by the language
	// should be removed after finish the test
	tempDir string

	// working directory to clone and test the project
	workingDir string

	// environment variables to test the project
	env []string
}

// cleanup removes working and temporal directory
func (l *languageConfig) cleanup() error {
	err := os.RemoveAll(l.workingDir)
	if err != nil {
		return fmt.Errorf("failed to remove the working directory '%s' %s", l.workingDir, err)
	}

	err = os.RemoveAll(l.tempDir)
	if err != nil {
		return fmt.Errorf("failed to remove the temporal directory '%s' %s", l.tempDir, err)
	}

	return nil
}

var supportedLanguages = map[string]newLanguageFunc{
	"Go": newGoLanguage,
}

var languagesDir = filepath.Join(pkgLibDir, "languages")

func init() {
	_ = os.MkdirAll(languagesDir, 0755)
}

// setup the language, creates a new language handler
func (l *RepoLanguage) setup() error {
	if len(l.Language) == 0 {
		return fmt.Errorf("missing repository language")
	}

	newLanguage, ok := supportedLanguages[l.Language]
	if !ok {
		return fmt.Errorf("language '%s' is not supported", l.Language)
	}

	var err error
	l.lang, err = newLanguage(l.Version)

	return err
}

// generateEnvironment generates a new languageEnvironment to test the project
func (l *RepoLanguage) generateEnvironment(projectSlug string) (languageConfig, error) {
	return l.lang.generateConfig(projectSlug)
}

// downloadFile downloads a file from a remote server
func downloadFile(url, dest string) error {
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
