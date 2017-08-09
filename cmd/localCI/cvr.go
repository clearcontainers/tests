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
	netUrl "net/url"
	"regexp"
	"time"
)

// repoBranchInfo contains information about a branch
type repoBranchInfo struct {
	// sha of the branch
	sha string
}

// pullRequestInfo contains information about a pull request
type pullRequestInfo struct {
	// branch name
	branch string

	// author of the pull request
	author string

	// mergeable specify if the pull request can be merged
	mergeable bool

	// state of the pull request
	state string
}

// RepoComment in the repository
type RepoComment struct {
	// User is the author of the comment
	User string

	// Comment of the comment
	Comment string

	// time when the comment was created
	time time.Time
}

// repoCommit in the repository
type repoCommit struct {
	sha  string
	time time.Time
}

// revision represents a source code revision of the repository
// it can be a branch or pull request
type revision interface {
	// canBeTested returns true if the revision can be tested
	canBeTested() error

	// download the source code of the revision inside the specific directory path
	download(path string) error

	// isBeingTested returns true if the revision is being tested
	isBeingTested() bool

	// id returns the id of this revision, pull request number, branch name, etc
	id() string

	// test the revision using the specific environment and running the stages
	test(config stageConfig, stages map[string]stage) error

	// equal compare two revisions, returns true if both are equals
	equal(r interface{}) bool

	// logDirName returns just the name of the logs directory, it could be
	// a pull request number, a SHA, etc
	logDirName() string
}

// CVR control version repository
type CVR interface {
	// getOpenPullRequests returns all open pull request
	getOpenPullRequests() ([]int, error)

	// getPullRequestCommits returns the commits of a pull request
	getPullRequestCommits(pr int) ([]repoCommit, error)

	// getBranchInfo returns information about a branch
	getBranchInfo(branch string) (repoBranchInfo, error)

	// getPullRequestInfo return information about a pull request
	getPullRequestInfo(pr int) (pullRequestInfo, error)

	// getProjectSlug returns the domain, owner and repo name separated by '/'
	getProjectSlug() string

	// getLatestPullRequestComment returns the latest comment of a specific
	// user in the specific pr. If user is an empty string then any user
	// could be the author of the latest comment. If body is an empty
	// string an error is returned.
	getLatestPullRequestComment(pr int, user, body string) (RepoComment, error)

	// downloadPullRequest downloads a specific pull request in the specified workingDir
	downloadPullRequest(pr int, branchName string, workingDir string) error

	// downloadBranch downloads a specific branch in the specific workingDir
	downloadBranch(branch string, workingDir string) error

	// createComment creates a comment in the specific pr
	createComment(pr int, comment string) error

	// isMember returns true if the user is member of the organization, else false
	isMember(user string) (bool, error)
}

const (
	githubDomain = "github.com"
)

// cvrs is the map of supported control repositories
var cvrs map[string]*regexp.Regexp

func init() {
	cvrs = make(map[string]*regexp.Regexp)
	cvrs[githubDomain] = regexp.MustCompile("http[s]{0,1}://" + githubDomain + "/[[:graph:]]")
	// by now just support github.com but would be nice to support other
	// control version repositories for example gitlab or bitbucket
}

// newCVR returns a new control version repository
func newCVR(url, token string) (CVR, error) {
	_, err := netUrl.ParseRequestURI(url)
	if err != nil {
		return nil, fmt.Errorf("failed to parse url %s %s", url, err)
	}

	for k, v := range cvrs {
		if v.MatchString(url) {
			switch k {
			case githubDomain:
				return newGithub(url, token)
			}
		}
	}

	return nil, fmt.Errorf("control version repository not supported: %s", url)
}
