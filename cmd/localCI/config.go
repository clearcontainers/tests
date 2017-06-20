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
	"io/ioutil"

	"github.com/BurntSushi/toml"
)

type config struct {
	RunTestsInParallel bool
	Repo               []Repo
}

// newConfig reads a configuration file returning a new config
func newConfig(file string) (*config, error) {
	if file == "" {
		return nil, fmt.Errorf("missing configuration file")
	}

	configuration, err := ioutil.ReadFile(file)
	if err != nil {
		return nil, err
	}

	var c config

	if err := toml.Unmarshal(configuration, &c); err != nil {
		return nil, err
	}

	ciLog.Debugf("configuration %+v", c)

	return &c, nil
}
