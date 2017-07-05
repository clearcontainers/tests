/// Copyright (c) 2017 Intel Corporation
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

	"github.com/BurntSushi/toml"
)

func TestHeaderRFC822(t *testing.T) {
	var conf Configuration
	var header string
	var expectHdr string

	expectHdr += "From: pnp@example.com\n"
	expectHdr += "To: maintainer@example.com,owner@example.com\n"
	expectHdr += "cc: contributor@example.com,developer@example.com\n"
	expectHdr += "Subject: PnP failure Report <no-reply>\n\n"

	if _, err := toml.DecodeFile("example.toml", &conf); err != nil {
		t.Fail()
	}

	header = HeaderRFC822(conf)
	if header != expectHdr {
		t.Fail()
	}
}
