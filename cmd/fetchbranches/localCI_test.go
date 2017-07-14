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
	"os"
	"strconv"
	"strings"
	"testing"
)

func TestLocalCIGetPR(t *testing.T) {
	ci := &localCI{}
	number := "1"

	os.Unsetenv(localCIPRNumberEnvar)

	if _, err := ci.GetPR(); err == nil {
		t.Fatal("expected an error")
	}

	os.Setenv(localCIPRNumberEnvar, "a")
	if _, err := ci.GetPR(); err == nil {
		t.Fatal("expected an error")
	}

	os.Setenv(localCIPRNumberEnvar, number)

	os.Unsetenv(localCIRepoSlugEnvar)
	if _, err := ci.GetPR(); err == nil {
		t.Fatal("expected an error")
	}

	os.Setenv(localCIRepoSlugEnvar, "clearcontainers")

	if _, err := ci.GetPR(); err == nil {
		t.Fatal("expected an error")
	}

	os.Setenv(localCIRepoSlugEnvar, "clearcontainers/")
	if _, err := ci.GetPR(); err == nil {
		t.Fatal("expected an error")
	}

	os.Setenv(localCIRepoSlugEnvar, "/tests")
	if _, err := ci.GetPR(); err == nil {
		t.Fatal("expected an error")
	}

	os.Setenv(localCIRepoSlugEnvar, "1")
	if _, err := ci.GetPR(); err == nil {
		t.Fatal("expected an error")
	}

	owner := "clearcontainers"
	repo := "test"
	os.Setenv(localCIRepoSlugEnvar, fmt.Sprintf("%s/%s", owner, repo))
	pr, err := ci.GetPR()
	if err != nil {
		t.Fatal("expected no error")
	}

	if strings.Compare(pr.owner, owner) != 0 {
		t.Fatalf("expected  %s == %s", pr.owner, owner)
	}

	if strings.Compare(pr.repo, repo) != 0 {
		t.Fatalf("expected  %s == %s", pr.repo, repo)
	}

	if strings.Compare(strconv.Itoa(pr.number), number) != 0 {
		t.Fatalf("expected  %d == %s", pr.number, number)
	}
}
