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
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

type stageTest struct {
	// name of the stage
	name string

	// commands of the stage
	commands []string

	// fail is true if the stage must fail, else false
	fail bool

	// stderr is the text that the stderr file must contain
	stderr string

	// stdout is the text that the stdout file must contain
	stdout string
}

func TestCanBeTested(t *testing.T) {
	assert := assert.New(t)

	pr := &PullRequest{}
	assert.Error(pr.canBeTested())

	pr.Commits = append(pr.Commits, PullRequestCommit{})
	assert.Error(pr.canBeTested())

	pr.CommentTrigger = &PullRequestComment{}
	assert.Error(pr.canBeTested())

	pr.Mergeable = true
	assert.NoError(pr.canBeTested())

	pr.Commits[0].Time = time.Now()
	assert.Error(pr.canBeTested())
}

func TestEqual(t *testing.T) {
	assert := assert.New(t)

	pr1 := &PullRequest{}
	pr2 := PullRequest{}
	assert.True(pr1.Equal(pr2))

	pr2.Commits = append(pr2.Commits, PullRequestCommit{Sha: "abc"})
	assert.False(pr1.Equal(pr2))

	pr1.Commits = pr2.Commits
	assert.True(pr1.Equal(pr2))

	pr1.Commits = []PullRequestCommit{{Sha: "xyz"}}
	assert.False(pr1.Equal(pr2))
}

func TestRunStage(t *testing.T) {
	var err error
	var stdout, stderr []byte
	assert := assert.New(t)

	pr := &PullRequest{}

	pr.LogDir, err = ioutil.TempDir("/tmp", ".logs")
	assert.NoError(err)
	defer os.RemoveAll(pr.LogDir)

	tests := []stageTest{
		{
			name:     "1",
			commands: []string{"echo -n 1"},
			fail:     false,
			stderr:   "",
			stdout:   "1",
		},
		{
			name:     "2",
			commands: []string{"(echo -n 2 >&2)"},
			fail:     false,
			stderr:   "2",
			stdout:   "",
		},
		{
			name:     "3",
			commands: []string{"(echo -n 3 >&2 && exit 1)"},
			fail:     true,
			stderr:   "3",
			stdout:   "",
		},
		{
			name:     "4",
			commands: []string{"(echo -n 4 && exit 1)"},
			fail:     true,
			stderr:   "",
			stdout:   "4",
		},
	}

	for _, t := range tests {
		err = pr.runStage(t.name, t.commands)
		if t.fail {
			assert.Error(err, "stage: %+v", t)
		} else {
			assert.NoError(err, "stage: %+v", t)
		}

		stderr, err = ioutil.ReadFile(fmt.Sprintf("%s/%s.stderr", pr.LogDir, t.name))
		assert.NoError(err)
		assert.Equal(t.stderr, string(stderr))

		stdout, err = ioutil.ReadFile(fmt.Sprintf("%s/%s.stdout", pr.LogDir, t.name))
		assert.NoError(err)
		assert.Equal(t.stdout, string(stdout))
	}
}
