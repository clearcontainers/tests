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
	"net/url"
	"os"
	"regexp"
	"strings"
)

// Branch is the structure providing specific parameter for the GetBranch execution
type Branch struct {
	Repo string
	URL  string
}

// Valid tag names
var tags = []string{"proxy", "shim", "tests", "hyperstart", "runtime"}

// GetBranch retrieves the branches from the comment
func GetBranch(comment string) []Branch {
	var branches []Branch

	for _, t := range tags {
		// Obtaining full name (branch and url)

		regex := regexp.MustCompile("branch_" + t + ":[[:space:]]*http[s]{0,1}:[[:graph:]]+")
		index := regex.FindStringIndex(comment)
		if len(index) == 0 {
			continue
		}

		// Valid syntax
		// i.e branch_test: https://xxxx.com/
		tag := comment[index[0]:index[1]]

		// Looking for the beginning of the URL (http)
		i := strings.Index(tag, "http")

		possibleURL := tag[i:]
		_, err := url.Parse(possibleURL)
		if err != nil {
			fmt.Fprintf(os.Stderr, "WARNING: ignoring url: %v\n", possibleURL)
			continue
		}

		b := Branch{
			Repo: t,
			URL:  possibleURL,
		}

		branches = append(branches, b)
	}

	return branches
}
