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
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestNewGithub(t *testing.T) {
	assert := assert.New(t)

	tests := []cvrTest{
		// malformed url
		{fmt.Sprintf("https//%s", githubDomain), true},

		// malformed url
		{"http://githubcom/", true},

		// unsupported cvr
		{"https://notsupported.com/", true},

		// missing owner
		{fmt.Sprintf("https://%s/", githubDomain), true},

		// missing repository
		{fmt.Sprintf("https://%s/clearcontainers", githubDomain), true},

		// right url
		{fmt.Sprintf("https://%s/clearcontainers/tests", githubDomain), false},
	}

	for _, t := range tests {
		cvr, err := newGithub(t.url, "")
		if t.fail {
			assert.Error(err)
			assert.Nil(cvr)
		} else {
			assert.NoError(err)
			assert.NotNil(cvr)
		}
	}
}

func TestGithubGetProjectSlug(t *testing.T) {
	assert := assert.New(t)
	projectSlug := fmt.Sprintf("%s/%s/%s", githubDomain, "clearcontainers", "tests")
	url := fmt.Sprintf("https://%s", projectSlug)

	cvr, err := newGithub(url, "")
	assert.NoError(err)

	assert.Equal(cvr.getProjectSlug(), projectSlug)
}
