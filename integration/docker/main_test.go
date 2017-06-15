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

package docker

import (
	"testing"

	. "github.com/clearcontainers/tests"
	. "github.com/onsi/ginkgo"
	. "github.com/onsi/gomega"
)

func TestIntegration(t *testing.T) {
	// before start we have to download the docker image
	cmd := NewCommand(Docker, "pull", Image)

	// 60 seconds should be enough to pull an image
	cmd.Timeout = 60

	if cmd == nil {
		t.Fatalf("failed to create command to pull docker image\n")
	}

	if cmd.Run() != 0 {
		t.Fatalf("failed to pull docker image: %s\n", cmd.Stderr.String())
	}

	RegisterFailHandler(Fail)
	RunSpecs(t, "Integration Suite")
}
