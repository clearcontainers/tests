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
	"bytes"
	"context"
	"fmt"
	"net/http"
	"os/exec"
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
	timeoutShortRequest = 60 * time.Second
	timeoutLongRequest  = 120 * time.Second
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

// getProjectSlug returns the domain, owner and repo name separated by '/'
func (g *Github) getProjectSlug() string {
	return fmt.Sprintf("%s/%s/%s", githubDomain, g.owner, g.repo)
}

// getRepoSlug returns the owner and the repo name separated by '/'
func (g *Github) getRepoSlug() string {
	return fmt.Sprintf("%s/%s", g.owner, g.repo)
}

// getPullRequestCommits returns the commits of a pull request
func (g *Github) getPullRequestCommits(pr int) ([]repoCommit, error) {
	ctx, cancel := context.WithTimeout(context.Background(), timeoutShortRequest)
	defer cancel()

	// get all commits of the pull request
	listCommits, _, err := g.client.PullRequests.ListCommits(ctx, g.owner, g.repo, pr, nil)
	if err != nil {
		return nil, err
	}

	var commits []repoCommit
	for _, c := range listCommits {
		if c == nil {
			return nil, fmt.Errorf("failed to get all commits of the pull request %d", pr)
		}

		if c.SHA == nil {
			return nil, fmt.Errorf("failed to get commit SHA of the pull request %d", pr)
		}
		sha := *c.SHA

		if c.Commit == nil || c.Commit.Committer == nil || c.Commit.Committer.Date == nil {
			return nil, fmt.Errorf("failed to get commit time of the pull request %d", pr)
		}
		time := *c.Commit.Committer.Date

		commits = append(commits,
			repoCommit{
				sha:  sha,
				time: time,
			},
		)
	}

	return commits, nil
}

// getOpenPullRequests returns the open pull requests
func (g *Github) getOpenPullRequests() ([]int, error) {
	ctx, cancel := context.WithTimeout(context.Background(), timeoutShortRequest)
	defer cancel()

	pullRequests, _, err := g.client.PullRequests.List(ctx, g.owner, g.repo, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to list pull requests %s", err)
	}

	prs := []int{}

	for _, pr := range pullRequests {
		if pr == nil || pr.Number == nil {
			continue
		}

		prs = append(prs, *pr.Number)
	}

	return prs, nil
}

// getBranchInfo returns a specific branch
func (g *Github) getBranchInfo(branch string) (repoBranchInfo, error) {
	i := repoBranchInfo{}

	ctx, cancel := context.WithTimeout(context.Background(), timeoutShortRequest)
	defer cancel()

	b, _, err := g.client.Repositories.GetBranch(ctx, g.owner, g.repo, branch)
	if err != nil {
		return i, err
	}

	if b.Commit == nil && b.Commit.SHA == nil {
		return i, fmt.Errorf("failed to get commit sha of branch %s", branch)
	}

	return repoBranchInfo{
		sha: *b.Commit.SHA,
	}, nil
}

// getPullRequestInfo return information about a pull request
func (g *Github) getPullRequestInfo(pr int) (pullRequestInfo, error) {
	i := pullRequestInfo{}

	ctx, cancel := context.WithTimeout(context.Background(), timeoutShortRequest)
	defer cancel()

	pullRequest, _, err := g.client.PullRequests.Get(ctx, g.owner, g.repo, pr)
	if err != nil {
		return i, err
	}

	// check the integrity of the pullRuest object before use it
	if pullRequest == nil {
		return i, fmt.Errorf("failed to get pull request %d", pr)
	}

	if pullRequest.User == nil || pullRequest.User.Login == nil {
		return i, fmt.Errorf("failed to get the author of the pull request %d", pr)
	}

	author := *pullRequest.User.Login

	// do not fail if we don't know if the pull request is
	// mergeable, just test it
	mergeable := true
	if pullRequest.Mergeable != nil {
		mergeable = *pullRequest.Mergeable
	}

	// include the state to check it later
	state := ""
	if pullRequest.State != nil {
		state = *pullRequest.State
	}

	if pullRequest.Head == nil || pullRequest.Head.Ref == nil {
		return i, fmt.Errorf("failed to get the branch name of the pull request %d", pr)
	}

	branch := *pullRequest.Head.Ref

	return pullRequestInfo{
		branch:    branch,
		author:    author,
		mergeable: mergeable,
		state:     state,
	}, nil
}

// getLatestPullRequestComment returns the latest comment of a specific
// user in the specific pr. If user is an empty string then any user
// could be the author of the latest comment. If body is an empty
// string an error is returned.
func (g *Github) getLatestPullRequestComment(pr int, user, body string) (RepoComment, error) {
	c := RepoComment{}

	if len(body) == 0 {
		return c, fmt.Errorf("body cannot be an empty string")
	}

	ctx, cancel := context.WithTimeout(context.Background(), timeoutLongRequest)
	defer cancel()

	comments, _, err := g.client.Issues.ListComments(ctx, g.owner, g.repo, pr, nil)
	if err != nil {
		return c, err
	}

	for i := len(comments) - 1; i >= 0; i-- {
		c := comments[i]
		if len(user) != 0 {
			if c.User == nil || c.User.Login == nil || *c.User.Login != user {
				continue
			}
		}

		if c.CreatedAt == nil {
			continue
		}

		if c.Body != nil && *c.Body == body {
			return RepoComment{
				User:    user,
				Comment: body,
				time:    *c.CreatedAt,
			}, nil
		}
	}

	return c, fmt.Errorf("comment '%s' not found", body)
}

func (g *Github) downloadRepo(workingDir string) error {
	var stderr bytes.Buffer

	// clone the project
	cmd := exec.Command("git", "clone", g.url, ".")
	cmd.Dir = workingDir
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to run git clone %s %s", stderr.String(), err)
	}

	return nil
}

func (g *Github) checkoutBranch(branch string, workingDir string) error {
	var stderr bytes.Buffer

	// checkout the branch
	stderr.Reset()
	cmd := exec.Command("git", "checkout", branch)
	cmd.Dir = workingDir
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to run git checkout %s %s", stderr.String(), err)
	}

	return nil
}

func (g *Github) downloadBranch(branch string, workingDir string) error {
	if err := g.downloadRepo(workingDir); err != nil {
		return err
	}

	if err := g.checkoutBranch(branch, workingDir); err != nil {
		return err
	}

	return nil
}

func (g *Github) downloadPullRequest(pr int, branch string, workingDir string) error {
	var stderr bytes.Buffer

	if err := g.downloadRepo(workingDir); err != nil {
		return err
	}

	// fetch the branch
	stderr.Reset()
	cmd := exec.Command("git", "fetch", "origin", fmt.Sprintf("pull/%d/head:%s", pr, branch))
	cmd.Dir = workingDir
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to run git fetch %s %s", stderr.String(), err)
	}

	if err := g.checkoutBranch(branch, workingDir); err != nil {
		return err
	}

	return nil
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
