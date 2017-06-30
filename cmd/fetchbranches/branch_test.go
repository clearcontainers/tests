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

import "testing"

func TestGetBranch(t *testing.T) {
	comment := "branch_hello: https://github.com"
	if branches := GetBranch(comment); len(branches) != 0 {
		t.Fatal("expected length 0")
	}

	comment = "branch : https://githbub.com"
	if branches := GetBranch(comment); len(branches) != 0 {
		t.Fatal("expected length 0")
	}

	comment = "1"
	if branches := GetBranch(comment); len(branches) != 0 {
		t.Fatal("expected length 0")
	}

	comment = "branch_tests"
	if branches := GetBranch(comment); len(branches) != 0 {
		t.Fatal("expected length 0")
	}

	comment = "https://githbub.com"
	if branches := GetBranch(comment); len(branches) != 0 {
		t.Fatal("expected length 0")
	}

	comment = "branchtests: https://github.com/clearcontainers/tests"
	if branches := GetBranch(comment); len(branches) != 0 {
		t.Fatal("expected length 0")
	}

	comment = "branch_tests:://github.com/clearcontainers/tests"

	if branches := GetBranch(comment); len(branches) != 0 {
		t.Fatal("expected length 0")
	}

	comment = "branch_tests:xxx://github.com/clearcontainers/tests"
	if branches := GetBranch(comment); len(branches) != 0 {
		t.Fatal("expected length 0")
	}

	comment = "tests: https://github.com/clearcontainers/tests"
	if branches := GetBranch(comment); len(branches) != 0 {
		t.Fatal("expected length 0")
	}

	comment = "branch_tests: https://github.com/clearcontainers/tests branch_runtime: https://github.com/clearcontainers/runtime"
	if branches := GetBranch(comment); len(branches) != 2 {
		t.Fatal("expected length 2")
	}
}
