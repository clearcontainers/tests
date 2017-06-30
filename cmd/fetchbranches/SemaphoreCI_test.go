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
	"os"
	"testing"
)

func TestGetPR(t *testing.T) {
	ci := &SemaphoreCI{}

	os.Unsetenv(prEnvar)

	if _, err := ci.GetPR(); err == nil {
		t.Fatal("expected an error")
	}

	os.Setenv(prEnvar, "a")
	if _, err := ci.GetPR(); err == nil {
		t.Fatal("expected an error")
	}

	os.Setenv(prEnvar, "1")

	os.Unsetenv(repoEnvar)
	if _, err := ci.GetPR(); err == nil {
		t.Fatal("expected an error")
	}

	os.Setenv(repoEnvar, "clearcontainers")

	if _, err := ci.GetPR(); err == nil {
		t.Fatal("expected an error")
	}

	os.Setenv(repoEnvar, "clearcontainers/")
	if _, err := ci.GetPR(); err == nil {
		t.Fatal("expected an error")
	}

	os.Setenv(repoEnvar, "/tests")
	if _, err := ci.GetPR(); err == nil {
		t.Fatal("expected an error")
	}

	os.Setenv(repoEnvar, "1")
	if _, err := ci.GetPR(); err == nil {
		t.Fatal("expected an error")
	}
}
