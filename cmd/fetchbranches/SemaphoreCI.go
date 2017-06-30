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

// Semaphore environment variables https://semaphoreci.com/docs/available-environment-variables.html

package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

type SemaphoreCI struct{}

const (
	prEnvar   = "PULL_REQUEST_NUMBER"
	repoEnvar = "SEMAPHORE_REPO_SLUG"
)

// GetPR retrieves the PR number from the Semaphore environment
func (ci *SemaphoreCI) GetPR() (*pr, error) {
	val := os.Getenv(prEnvar)

	if val == "" {
		return nil, fmt.Errorf("%v environment variable is empty", prEnvar)
	}

	number, err := strconv.Atoi(val)
	if err != nil {
		return nil, err
	}

	semaphoreRepository := os.Getenv(repoEnvar)

	// Checks that repository name is not empty
	if semaphoreRepository == "" {
		return nil, fmt.Errorf("%v environment variable is empty", repoEnvar)
	}

	testRepository := strings.Split(semaphoreRepository, "/")

	// Valid names should have and owner and a repository name
	if len(testRepository) != 2 {
		return nil, fmt.Errorf("invalid repository name: %v", semaphoreRepository)
	}

	ownerName := testRepository[0]
	repositoryName := testRepository[1]

	// Checks that the owner name is not empty
	if ownerName == "" {
		return nil, fmt.Errorf("missing an owner name: %v", semaphoreRepository)
	}

	// Checks that the repository name is not empty
	if repositoryName == "" {
		return nil, fmt.Errorf("missing a repository name: %v", semaphoreRepository)
	}

	return &pr{
		number: number,
		owner:  ownerName,
		repo:   repositoryName,
	}, nil
}
