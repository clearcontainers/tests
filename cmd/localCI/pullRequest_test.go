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

	// output is the text that the output file must contain
	output string
}

func TestPullRequestCanBeTested(t *testing.T) {
	assert := assert.New(t)

	pr := &pullRequest{}
	assert.Error(pr.canBeTested())

	pr.commits = append(pr.commits, repoCommit{})
	assert.Error(pr.canBeTested())

	pr.commentTrigger = &RepoComment{}
	assert.Error(pr.canBeTested())

	pr.info.mergeable = true
	assert.NoError(pr.canBeTested())

	pr.commits[0].time = time.Now()
	assert.Error(pr.canBeTested())
}

func TestPullRequestEqual(t *testing.T) {
	assert := assert.New(t)

	var pr1, pr2 revision

	pr1 = &pullRequest{}
	pr2 = &pullRequest{}
	assert.True(pr1.equal(pr2))
	assert.False(pr1.equal(pullRequest{}))

	pr2.(*pullRequest).repoBranch.info.sha = "abc"
	assert.False(pr1.equal(pr2))

	pr1.(*pullRequest).repoBranch = pr2.(*pullRequest).repoBranch
	assert.True(pr1.equal(pr2))

	pr1.(*pullRequest).repoBranch.info.sha = "xyz"
	assert.False(pr1.equal(pr2))

	assert.False(pr1.equal(pullRequest{}))
}
