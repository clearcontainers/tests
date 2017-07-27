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
	"time"
)

// PullRequestComment represents a user comment
type PullRequestComment struct {
	User    string
	Comment string
	time    time.Time
}

// PullRequestCommit represents a commit in the pull request
type PullRequestCommit struct {
	Sha  string
	Time time.Time
}

// PullRequest represents a pull request
// present in a control version repository
type PullRequest struct {
	// Number of the pull request
	Number int

	// Commits in the pull request
	Commits []PullRequestCommit

	// Author of the pull request
	Author string

	// Mergeable specify if the pull request can be merged
	Mergeable bool

	// BranchName of the pull request
	BranchName string

	// CommentTrigger is the comment that must be present to trigger the test
	// also it is used to ensure that the pull request is tested only when
	// the comment appears after the list of commits
	CommentTrigger *PullRequestComment

	// BeingTested is true if the pull request is being tested, else false
	BeingTested bool

	// WorkingDir is the working directory to test this pull request
	WorkingDir string

	// LogDir is the log directory for the pull request
	LogDir string

	// Env has the environment variables used to run the commands of each stage
	Env []string
}

// canBeTested returns an error if the pull request cannot be tested
func (pr *PullRequest) canBeTested() error {
	if !pr.Mergeable {
		err := fmt.Errorf("the pull request is not mergeable")
		ciLog.Debug(err.Error())
		return err
	}

	commitsLen := len(pr.Commits)
	if commitsLen == 0 {
		err := fmt.Errorf("there are no commits to test")
		ciLog.Debug(err.Error())
		return err
	}

	// there is no comment trigger so we can test
	if pr.CommentTrigger == nil {
		ciLog.Debugf("comment trigger of pull request %+v is empty", pr)
		return nil
	}

	latestCommit := pr.Commits[commitsLen-1]
	if pr.CommentTrigger.time.Unix() < latestCommit.Time.Unix() {
		err := fmt.Errorf("there are new commits after latest comment trigger %+v", pr.CommentTrigger)
		ciLog.Debugf(err.Error())
		return err
	}

	return nil
}

// Equal returns true is both pull requests have the same commits
func (pr *PullRequest) Equal(rpr PullRequest) bool {
	if len(pr.Commits) != len(rpr.Commits) {
		return false
	}

	for i, c := range pr.Commits {
		if strings.Compare(c.Sha, rpr.Commits[i].Sha) != 0 {
			return false
		}
	}

	return true
}

// runStage runs a specific stage with the specific commands
func (pr *PullRequest) runStage(stage string, commands []string) error {
	outFile := filepath.Join(pr.LogDir, stage)
	output, err := os.OpenFile(outFile, os.O_WRONLY|os.O_APPEND|os.O_CREATE, logFileMode)
	if err != nil {
		return err
	}
	defer output.Close()

	for _, c := range commands {
		cmd := exec.Command("bash", "-c", c)
		cmd.Stdout = output
		cmd.Stderr = output
		cmd.Env = pr.Env
		cmd.Dir = pr.WorkingDir

		if err := cmd.Run(); err != nil {
			return err
		}
	}

	return nil
}
