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

func TestNewCI(t *testing.T) {
	os.Unsetenv(ciEnvar)

	if ci := NewCI(); ci != nil {
		t.Fatal("expected an error")
	}

	os.Setenv(ciEnvar, "false")
	os.Unsetenv(toolEnvar)

	if ci := NewCI(); ci != nil {
		t.Fatal("expected an error")
	}

	os.Setenv(toolEnvar, "false")

	if ci := NewCI(); ci != nil {
		t.Fatal("expected an error")
	}

	os.Setenv(ciEnvar, "1")
	os.Setenv(toolEnvar, "2")

	if ci := NewCI(); ci != nil {
		t.Fatal("expected an error")
	}

	os.Setenv(ciEnvar, "true")
	os.Setenv(toolEnvar, "false")

	if ci := NewCI(); ci != nil {
		t.Fatal("expected an error")
	}

	os.Setenv(ciEnvar, "false")
	os.Setenv(toolEnvar, "true")

	if ci := NewCI(); ci != nil {
		t.Fatal("expected an error")
	}

	os.Setenv(ciEnvar, "true")

	if ci := NewCI(); ci == nil {
		t.Fatal("expected an error")
	}

}
