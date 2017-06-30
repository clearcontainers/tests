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
	"strings"
)

const (
	urlCVR          = "github.com"
	wordKey         = "/tree/"
	githubDirectory = "/src/github.com/"
)

func main() {
	ci := NewCI()

	if ci == nil {
		fmt.Fprintf(os.Stderr, "CI not found\n")
		os.Exit(1)
	}

	// Shows PR number, owner and repository names
	pr, err := ci.GetPR()

	if err != nil {
		fmt.Printf("ERROR: %v\n", err)
		os.Exit(1)
	}
	fmt.Printf("PULL_REQUEST_NUMBER : %d, OWNER : %s, REPOSITORY: %s\n", pr.number, pr.owner, pr.repo)

	// Shows author PR comments
	comments, err := pr.GetAuthorComments()
	fmt.Printf("%#v\n", comments)

	// Obtains the repo and the URL where a PR will be fetched
	fetchMap := make(map[string]string)

	for _, a := range comments {
		branches := GetBranch(a)
		for _, b := range branches {
			fetchMap[b.Repo] = b.URL
		}
	}

	if err := fetchBranches(fetchMap, *pr); err != nil {
		fmt.Printf("ERROR: %v\n", err)
		os.Exit(1)
	}

}

func fetchBranches(fetchMap map[string]string, pr pr) error {
	// Checks that GOPATH exists
	envVar := "GOPATH"
	gopath := os.Getenv(envVar)
	if gopath == "" {
		return fmt.Errorf("%v environment variable is empty", envVar)
	}

	for branchRepo, branchURL := range fetchMap {
		// Clones the repository that is in the PR (branch name)
		testRepository := filepath.Join(urlCVR, pr.owner, branchRepo)
		cmd := exec.Command("go", "get", "-d", testRepository)
		err := cmd.Run()

		if err != nil {
			return fmt.Errorf("Failed to clone the repository: %v", testRepository)
		}

		// Obtains the name of the branch i.e. topic/tests
		// from the URL
		i := strings.Index(branchURL, wordKey)

		if i == -1 {
			return fmt.Errorf("Failed to establish branch name from URL: %v", branchURL)
		}

		branchName := (branchURL[i+len(wordKey):])

		// Performs the fetch
		fullDirectory := filepath.Join(gopath, githubDirectory)
		fetchDirectory := filepath.Join(fullDirectory, pr.owner, branchRepo)
		os.Chdir(fetchDirectory)

		cmd = exec.Command("git", "fetch", "origin")
		nameFetch := filepath.Join("origin", branchName)
		cmd = exec.Command("git", "checkout", "-b", branchName, nameFetch)
		err = cmd.Run()

		if err != nil {
			return fmt.Errorf("Failed to fetch: %v", branchName)
		}
	}

	return nil

}
