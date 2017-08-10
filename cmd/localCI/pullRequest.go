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
	"strconv"
	"strings"

	"github.com/Sirupsen/logrus"
)

type pullRequestConfig struct {
	// cvr control version repository
	cvr CVR

	// logger of the pull request
	logger *logrus.Entry

	// commentTrigger is the comment that must be present to test
	// this pull request, if comment is empty then no comment is needed
	commentTrigger RepoComment

	// postOnSuccess is the comment to post if test finished correctly
	postOnSuccess string

	// postOnFailure is the comment to post if test failed
	postOnFailure string

	// whitelist is the list of users whose pull request can be tested
	whitelist string
}

// pullRequest represents a pull request
// present in a control version repository
type pullRequest struct {
	// repoBranch of the pull request
	repoBranch

	// info of the pull request
	info pullRequestInfo

	// number of the pull request
	number int

	// commits in the pull request
	commits []repoCommit

	// whitelist is the list of users whose pull request can be tested
	whitelist string

	// commentTrigger is the comment that must be present to trigger the test
	// also it is used to ensure that the pull request is tested only when
	// the comment appears after the list of commits
	commentTrigger *RepoComment

	// postOnSuccess is the comment to post if test finished correctly
	postOnSuccess string

	// postOnFailure is the comment to post if test failed
	postOnFailure string
}

// newPullRequest returns a new pullRequest object
func newPullRequest(pr int, config pullRequestConfig) (*pullRequest, error) {
	logger := config.logger
	cvr := config.cvr

	logger.Debugf("creating pull request: %d", pr)

	i, err := cvr.getPullRequestInfo(pr)
	if err != nil {
		return nil, fmt.Errorf("failed to get pull request info %s", err)
	}

	logger.Debugf("pull request %d info: %+v", pr, i)

	commits, err := cvr.getPullRequestCommits(pr)
	if err != nil {
		return nil, fmt.Errorf("failed to get pull request commits %s", err)
	}

	var shas string
	for _, c := range commits {
		shas += c.sha + ","
	}

	var commentTrigger *RepoComment
	if len(config.commentTrigger.Comment) != 0 {
		comment, err := cvr.getLatestPullRequestComment(pr, config.commentTrigger.User,
			config.commentTrigger.Comment)
		if err == nil {
			commentTrigger = &comment
		}
	}

	logger.Debugf("pull request %d comment trigger: %#v", pr, commentTrigger)

	return &pullRequest{
		repoBranch: repoBranch{
			info:        repoBranchInfo{sha: shas},
			name:        i.branch,
			cvr:         cvr,
			beingTested: false,
			logger:      logger,
		},
		info:           i,
		number:         pr,
		commits:        commits,
		whitelist:      config.whitelist,
		commentTrigger: commentTrigger,
		postOnFailure:  config.postOnFailure,
		postOnSuccess:  config.postOnSuccess,
	}, nil
}

func (pr *pullRequest) authorInWhitelist() bool {
	for _, u := range strings.Split(pr.whitelist, ",") {
		switch u {
		// check if user is a member of the organization
		case "@":
			author := pr.info.author
			ok, err := pr.repoBranch.cvr.isMember(author)
			if ok {
				return true
			}
			if err != nil {
				pr.repoBranch.logger.Errorf("unable to know if user %s is a member of the organization: %s",
					author, err)
			}
		// any pull request can be tested
		case "*":
			return true

		// specific users
		default:
			if u == pr.info.author {
				return true
			}
		}
	}

	return false
}

// canBeTested returns an error if the pull request cannot be tested
func (pr *pullRequest) canBeTested() error {
	if !pr.info.mergeable {
		return fmt.Errorf("the pull request is not mergeable")
	}

	commitsLen := len(pr.commits)
	if commitsLen == 0 {
		return fmt.Errorf("there are no commits to test")
	}

	latestCommit := pr.commits[commitsLen-1]
	if pr.commentTrigger != nil && pr.commentTrigger.time.Unix() < latestCommit.time.Unix() {
		return fmt.Errorf("there are new commits after latest comment trigger %+v", *pr.commentTrigger)
	}

	if pr.info.state == "closed" {
		return fmt.Errorf("the state of pull request %d is %s", pr.number, pr.info.state)
	}

	if len(pr.whitelist) > 0 && !pr.authorInWhitelist() {
		return fmt.Errorf("the author of the pull request is not in the whitelist")
	}

	return nil
}

// download the source code of the revision inside the specific directory path
func (pr *pullRequest) download(path string) error {
	pr.repoBranch.logger.Debugf("downloading pull request %d", pr.number)

	return pr.repoBranch.cvr.downloadPullRequest(pr.number, pr.repoBranch.name, path)
}

func (pr *pullRequest) test(config stageConfig, stages map[string]stage) error {
	pr.repoBranch.logger.Debugf("testing pull request %d", pr.number)

	envars := []string{fmt.Sprintf("LOCALCI_PR_NUMBER=%d", pr.number)}
	config.env = append(config.env, envars...)

	err := pr.repoBranch.test(config, stages)
	postMsg := pr.postOnSuccess
	if err != nil {
		postMsg = pr.postOnFailure
	}

	// do not try to post empty messages
	if len(postMsg) == 0 {
		return err
	}

	if e := pr.repoBranch.cvr.createComment(pr.number, postMsg); e != nil {
		pr.repoBranch.logger.Errorf("failed to create comment on pull request %d: %s",
			pr.number, e)
	}

	return err
}

func (pr *pullRequest) id() string {
	return strconv.Itoa(pr.number)
}

func (pr *pullRequest) equal(r interface{}) bool {
	rpr, ok := r.(*pullRequest)
	if !ok {
		return false
	}

	return pr.repoBranch.equal((revision)(&rpr.repoBranch))
}

func (pr *pullRequest) logDirName() string {
	return pr.id()
}
