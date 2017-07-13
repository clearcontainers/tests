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

// localCI environment variables https://github.com/clearcontainers/tests/blob/master/cmd/localCI/README.rst#environment-variables

package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

type localCI struct{}

const (
	localCIPRNumberEnvar = "LOCALCI_PR_NUMBER"
	localCIRepoSlugEnvar = "LOCALCI_REPO_SLUG"
)

func (ci *localCI) GetPR() (*pr, error) {
	val := os.Getenv(localCIPRNumberEnvar)

	if len(val) == 0 {
		return nil, fmt.Errorf("%s environment variable is empty", localCIPRNumberEnvar)
	}

	prNumber, err := strconv.Atoi(val)
	if err != nil {
		return nil, err
	}

	repoSlug := os.Getenv(localCIRepoSlugEnvar)

	if len(repoSlug) == 0 {
		return nil, fmt.Errorf("%s environment variable is empty", repoSlug)
	}

	ownerRepo := strings.Split(repoSlug, "/")

	if len(ownerRepo) != 2 {
		return nil, fmt.Errorf("invalid repository name: %s", repoSlug)
	}

	ownerName := ownerRepo[0]
	repositoryName := ownerRepo[1]

	if ownerName == "" {
		return nil, fmt.Errorf("missing an owner name: %v", repoSlug)
	}

	// Checks that the repository name is not empty
	if repositoryName == "" {
		return nil, fmt.Errorf("missing a repository name: %v", repoSlug)
	}

	return &pr{
		number: prNumber,
		owner:  ownerName,
		repo:   repositoryName,
	}, nil
}
