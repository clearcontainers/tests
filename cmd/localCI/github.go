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
	"context"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/google/go-github/github"
	"golang.org/x/oauth2"
)

// Github represents a control version repository to
// interact with github.com
type Github struct {
	client *github.Client
	owner  string
	repo   string
	url    string
}

const (
	timeoutShortRequest = 10 * time.Second
	timeoutLongRequest  = 20 * time.Second
)

// newGithub returns an object of type Github
func newGithub(url, token string) (CVR, error) {
	url = strings.TrimSpace(url)

	ownerRepo := strings.SplitAfter(url, "/"+githubDomain+"/")

	// at least we need two tokens
	if len(ownerRepo) < 2 {
		return nil, fmt.Errorf("missing owner and repo %s", url)
	}

	ownerRepo = strings.Split(ownerRepo[1], "/")

	// at least we need two tokens: owner and repo
	if len(ownerRepo) < 2 {
		return nil, fmt.Errorf("failed to get owner and repo %s", url)
	}

	if len(ownerRepo[0]) == 0 {
		return nil, fmt.Errorf("missing owner in url %s", url)
	}

	if len(ownerRepo[1]) == 0 {
		return nil, fmt.Errorf("missing repository in url %s", url)
	}

	// create a new http client using the token
	var client *http.Client
	if token != "" {
		ts := oauth2.StaticTokenSource(
			&oauth2.Token{AccessToken: token},
		)
		client = oauth2.NewClient(context.Background(), ts)
	}

	return &Github{
		client: github.NewClient(client),
		owner:  ownerRepo[0],
		repo:   ownerRepo[1],
		url:    url,
	}, nil
}

// getDomain returns the domain name
func (g *Github) getDomain() string {
	return githubDomain
}

// getOwner returns the owner of the repo
func (g *Github) getOwner() string {
	return g.owner
}

// getRepo returns the repository name
func (g *Github) getRepo() string {
	return g.repo
}

// getOpenPullRequests returns the open pull requests
func (g *Github) getOpenPullRequests() (map[string]*PullRequest, error) {
	ctx, cancel := context.WithTimeout(context.Background(), timeoutShortRequest)
	defer cancel()

	pullRequests, _, err := g.client.PullRequests.List(ctx, g.owner, g.repo, nil)
	if err != nil {
		ciLog.Errorf("failed to list pull requests: %s", err)
		return nil, err
	}

	prs := make(map[string]*PullRequest)

	for _, pr := range pullRequests {
		pullRequest, err := g.getPullRequest(*pr.Number)
		if err != nil {
			ciLog.Errorf("failed to get pull request %d: %s", *pr.Number, err)
			continue
		}

		prs[strconv.Itoa(*pr.Number)] = pullRequest
	}

	return prs, nil
}

// getPullRequest returns a specific pull request
func (g *Github) getPullRequest(pr int) (*PullRequest, error) {
	ctx, cancel := context.WithTimeout(context.Background(), timeoutShortRequest)
	defer cancel()

	// get all commits of the pull request
	listCommits, _, err := g.client.PullRequests.ListCommits(ctx, g.owner, g.repo, pr, nil)
	if err != nil {
		return nil, err
	}

	var commits []PullRequestCommit
	for _, c := range listCommits {
		commits = append(commits,
			PullRequestCommit{
				Sha:  *c.SHA,
				Time: *c.Commit.Committer.Date,
			},
		)
	}

	pullRequest, _, err := g.client.PullRequests.Get(ctx, g.owner, g.repo, pr)
	if err != nil {
		return nil, err
	}

	return &PullRequest{
		Number:  pr,
		Commits: commits,
		Author:  *pullRequest.User.Login,
	}, nil
}

// getLatestPullRequestComment returns the latest comment of a specific
// user in the specific pr. If comment.User is an empty string then any user
// could be the author of the latest pull request. If comment.Comment is an empty
// string an error is returned.
func (g *Github) getLatestPullRequestComment(pr int, comment PullRequestComment) (*PullRequestComment, error) {
	if len(comment.Comment) == 0 {
		return nil, fmt.Errorf("comment cannot be an empty string")
	}

	ctx, cancel := context.WithTimeout(context.Background(), timeoutLongRequest)
	defer cancel()

	comments, _, err := g.client.Issues.ListComments(ctx, g.owner, g.repo, pr, nil)
	if err != nil {
		return nil, err
	}

	for i := len(comments) - 1; i >= 0; i-- {
		c := comments[i]
		if len(comment.User) != 0 {
			if strings.Compare(*c.User.Login, comment.User) != 0 {
				continue
			}
		}

		if strings.Compare(*c.Body, comment.Comment) == 0 {
			return &PullRequestComment{
				User:    comment.User,
				Comment: comment.Comment,
				time:    *c.CreatedAt,
			}, nil
		}
	}

	return nil, fmt.Errorf("comment '%+v' not found", comment)
}

func (g *Github) downloadPullRequest(pr int, workingDirectory string) (string, error) {
	projectDirectory, err := filepath.Abs(workingDirectory)
	if err != nil {
		return "", err
	}

	projectDirectory = filepath.Join(projectDirectory, g.repo)
	if err := os.MkdirAll(projectDirectory, 0755); err != nil {
		return "", fmt.Errorf("failed to create project directory %s", err)
	}

	cmd := exec.Command("git", "clone", g.url, ".")
	cmd.Dir = projectDirectory
	if err := cmd.Run(); err != nil {
		return "", fmt.Errorf("failed to clone project %s", err)
	}

	cmd = exec.Command("git", "pull", "--no-edit", "origin", fmt.Sprintf("pull/%d/head", pr))
	cmd.Dir = projectDirectory
	if err := cmd.Run(); err != nil {
		return "", fmt.Errorf("failed to pull request %s", err)
	}

	return projectDirectory, nil
}

// createComment creates a comment in the specific pr
func (g *Github) createComment(pr int, comment string) error {
	ctx, cancel := context.WithTimeout(context.Background(), timeoutLongRequest)
	defer cancel()

	c := &github.IssueComment{Body: &comment}

	_, _, err := g.client.Issues.CreateComment(ctx, g.owner, g.repo, pr, c)

	return err
}

// isMember returns true if the user is member of the organization, else false
func (g *Github) isMember(user string) (bool, error) {
	ctx, cancel := context.WithTimeout(context.Background(), timeoutShortRequest)
	defer cancel()

	ret, _, err := g.client.Organizations.IsMember(ctx, g.owner, user)

	return ret, err
}
