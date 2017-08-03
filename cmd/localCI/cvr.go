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
)

// CVR control version repository
type CVR interface {
	// getOpenPullRequests returns all open pull request
	getOpenPullRequests() (map[string]*PullRequest, error)

	// getPullRequest returns a specific pull request
	getPullRequest(pr int) (*PullRequest, error)

	// getDomain returns the domain of the control version repository
	getDomain() string

	// getOwner returns the owner of the repository
	getOwner() string

	// getRepo returns the repository name
	getRepo() string

	// getLatestPullRequestComment returns the latest comment of a specific
	// user in the specific pr. If comment.User is an empty string then any user
	// could be the author of the latest pull request. If comment.Comment is an empty
	// string an error is returned.
	getLatestPullRequestComment(pr int, comment PullRequestComment) (*PullRequestComment, error)

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

// newCvr returns a new control version repository
func newCvr(url, token string) (CVR, error) {
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
