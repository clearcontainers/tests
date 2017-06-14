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

	"github.com/google/go-github/github"
)

// pr struct needs a number that represents the pull request,
// and owner and a repository name (i.e. clearcontainers/runtime)
type pr struct {
	number int
	owner  string
	repo   string
}

func (p *pr) GetAuthorComments() ([]string, error) {
	var comments []string
	client := github.NewClient(nil)

	// Retrieves the commit message from the PR
	message, _, err := client.PullRequests.Get(context.Background(), p.owner, p.repo, p.number)

	if err != nil {
		return comments, err
	}

	// Retrieves the author of the PR
	prAuthor := message.User.GetLogin()

	// Checks that commit message has an author
	if prAuthor == "" {
		return comments, fmt.Errorf("author is missing in the commit message of the PR")
	}

	if message.GetBody() != "" {
		comments = append(comments, message.GetBody())
	}

	// Retrieves the comments of the PR
	prComments, _, err := client.Issues.ListComments(context.Background(), p.owner, p.repo, p.number, nil)
	if err != nil {
		return comments, err
	}

	for _, c := range prComments {
		prAuthorComment := c.User.GetLogin()
		// Displays only the comments of the author of the PR
		if prAuthor == prAuthorComment {
			comments = append(comments, c.GetBody())
		}
	}

	return comments, nil
}
