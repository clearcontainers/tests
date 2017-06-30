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

import "os"

// CI Continous Integration
type CI interface {
	// GetPR obtains the pull request number
	GetPR() (*pr, error)
}

// Semaphore environment variables
const (
	ciEnvar   = "CI"
	toolEnvar = "SEMAPHORE"
)

// NewCI verifies that the testing environment is using Semaphore
func NewCI() CI {
	ci := os.Getenv(ciEnvar)
	semaphore := os.Getenv(toolEnvar)
	if ci == "true" && semaphore == "true" {
		return &SemaphoreCI{}
	}
	return nil
}
