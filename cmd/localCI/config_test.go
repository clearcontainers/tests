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
	"testing"

	"github.com/stretchr/testify/assert"
)

const configuration = `
[[Repo]]
url = "https://github.com/clearcontainers/runtime"
run = [ ".ci/run.sh" ]
[Repo.language]
  language = "Go"
  version = "go1.8.3"
`

const configurationWithErrors = `
[[Repo]
url = https://github.com/clearcontainers/runtime"
run = [ ".ci/run.sh" ]
[Repo.language]
  language: "Go"
  version = "go1.8.3"
`

func TestNewConfig(t *testing.T) {
	var configFile *os.File
	var err error
	var conf *config
	assert := assert.New(t)

	conf, err = newConfig("")
	assert.Error(err)
	assert.Nil(conf)

	// load a configuration file that does not exist
	conf, err = newConfig("/wxyz/123/abc")
	assert.Error(err)
	assert.Nil(conf)

	// Test a configuration with errors
	configFile, err = ioutil.TempFile("/tmp", ".config.toml.")
	assert.NoError(err)
	assert.NotNil(configFile)
	defer os.Remove(configFile.Name())
	defer configFile.Close()

	_, err = configFile.WriteString(configurationWithErrors)
	assert.NoError(err)
	conf, err = newConfig(configFile.Name())
	assert.Error(err)
	assert.Nil(conf)

	// Test a good configuration
	configFile, err = ioutil.TempFile("/tmp", ".config.toml.")
	assert.NoError(err)
	assert.NotNil(configFile)
	defer os.Remove(configFile.Name())
	defer configFile.Close()

	_, err = configFile.WriteString(configuration)
	assert.NoError(err)
	conf, err = newConfig(configFile.Name())
	assert.NoError(err)
	assert.NotNil(conf)
}
