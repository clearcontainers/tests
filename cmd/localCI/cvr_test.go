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
	"testing"

	"github.com/stretchr/testify/assert"
)

type cvrTest struct {
	url  string
	fail bool
}

func TestNewCvr(t *testing.T) {
	assert := assert.New(t)

	tests := []cvrTest{
		// malformed url
		{"http//url.com", true},

		// malformed url
		{"http://noturl/", true},

		// missing http
		{"url.com/", true},

		// unsupported cvr
		{"https://notsupported.com/", true},

		// supported url
		{"https://github.com/clearcontainers/tests", false},
	}

	for _, t := range tests {
		cvr, err := newCvr(t.url, "")
		if t.fail {
			assert.Error(err)
			assert.Nil(cvr)
		} else {
			assert.NoError(err)
			assert.NotNil(cvr)
		}
	}
}
