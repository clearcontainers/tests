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
	"io/ioutil"
	"os"
	"path/filepath"
	"testing"

	"github.com/Sirupsen/logrus"
	"github.com/stretchr/testify/assert"
)

func TestStageRun(t *testing.T) {
	var err error
	var output []byte
	assert := assert.New(t)

	sc := stageConfig{
		logger: logrus.WithFields(logrus.Fields{"test": "test"}),
	}

	sc.logDir, err = ioutil.TempDir("/tmp", ".logs")
	assert.NoError(err)
	defer os.RemoveAll(sc.logDir)

	s := stage{
		name: "test",
	}

	// missing commands
	assert.Error(s.run(sc))

	tests := []stageTest{
		{
			name:     "1",
			commands: []string{"echo -n 1"},
			fail:     false,
			output:   "1",
		},
		{
			name:     "2",
			commands: []string{"(echo -n 2 >&2)"},
			fail:     false,
			output:   "2",
		},
		{
			name:     "3",
			commands: []string{"(echo -n 3 >&2 && exit 1)"},
			fail:     true,
			output:   "3",
		},
		{
			name:     "4",
			commands: []string{"(echo -n 4 && exit 1)"},
			fail:     true,
			output:   "4",
		},
	}

	for _, t := range tests {
		s := &stage{
			name:     t.name,
			commands: t.commands,
		}

		err = s.run(sc)
		if t.fail {
			assert.Error(err, "stage: %+v", s)
		} else {
			assert.NoError(err, "stage: %+v", s)
		}

		output, err = ioutil.ReadFile(filepath.Join(sc.logDir, t.name))
		assert.NoError(err)
		assert.Equal(t.output, string(output))
	}
}
