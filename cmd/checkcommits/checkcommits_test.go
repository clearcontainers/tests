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
	"regexp"
	"strings"
	"testing"
)

var fixesString string
var fixesPattern *regexp.Regexp

func createCommitConfig() (config *CommitConfig) {
	return NewCommitConfig(true, true,
		fixesString,
		"Signed-off-by",
		defaultMaxBodyLineLength,
		defaultMaxSubjectLineLength)
}

func init() {
	fixesString = "Fixes"
	fixesPattern = regexp.MustCompile(fmt.Sprintf("(?i)%s:* *#\\d+", fixesString))
}

func TestCheckCommits(t *testing.T) {

	err := checkCommits(nil, nil)
	if err == nil {
		t.Fatal("expected failure")
	}

	config := &CommitConfig{}
	err = checkCommits(config, nil)
	if err == nil {
		t.Fatalf("expected failure")
	}

	err = checkCommits(config, []string{})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	invalidCommits := []string{
		"hello",
		"foo bar",
		"what is this?",
		"don't know!",
		"9999999999999999999999999999999999999999",
		"abcdef",
		"0123456789",
		"gggggggggggggggggggggggggggggggggggggggg",
		"ggggggggggggggggggggggggggggggggggggggggh",
	}

	err = checkCommits(nil, invalidCommits)
	if err == nil {
		t.Fatalf("expected an error")
	}

	err = checkCommits(config, invalidCommits)
	if err == nil {
		t.Fatalf("expected an error")
	}
}

func TestCheckCommit(t *testing.T) {
	err := checkCommit(nil, "")
	if err == nil {
		t.Errorf("expected error when no config specified")
	}

	config := NewCommitConfig(true, true, "", "", 0, 0)
	err = checkCommit(config, "")
	if err == nil {
		t.Errorf("expected error when no commit specified")
	}
}

func TestCheckCommitSubject(t *testing.T) {
	config := createCommitConfig()

	type testData struct {
		commit      string
		subject     string
		config      *CommitConfig
		expectFail  bool
		expectFixes bool
	}

	data := []testData{
		// invalid commit
		{"", "", nil, true, false},
		{"", "A subject", nil, true, false},
		{"", "subsystem: A subject", nil, true, false},
		{"", "subsystem: much too long!!!", nil, true, false},
		{"", "this subject is much too long!!!", nil, true, false},
		{"", "foo", config, true, false},
		{"", "bar", nil, true, false},
		{"", "baz", config, true, false},
		{"", "subsystem: A subject", config, true, false},
		{"", strings.Repeat("a", (defaultMaxSubjectLineLength/2)-1), nil, true, false},
		{"", strings.Repeat("b", defaultMaxSubjectLineLength/2), nil, true, false},
		{"", strings.Repeat("c", (defaultMaxSubjectLineLength/2)+1), nil, true, false},
		{"", strings.Repeat("d:", (defaultMaxSubjectLineLength/2)-1), nil, true, false},
		{"", strings.Repeat("e:", defaultMaxSubjectLineLength/2), nil, true, false},
		{"", strings.Repeat("f:", (defaultMaxSubjectLineLength/2)+1), nil, true, false},

		// invalid subject
		{"HEAD", "", nil, true, false},
		{"HEAD", "", config, true, false},
		{"HEAD", "", nil, true, false},
		{"HEAD", "", config, true, false},
		{"HEAD", "          ", config, true, false},
		{"HEAD", "\t\t\t", config, true, false},
		{"HEAD", "\n", config, true, false},
		{"HEAD", "\r", config, true, false},
		{"HEAD", "\r\n", config, true, false},
		{"HEAD", "\n\r", config, true, false},
		{"HEAD", " \n\r", config, true, false},
		{"HEAD", "\n\r ", config, true, false},
		{"HEAD", " \n\r ", config, true, false},
		{"HEAD", "invalid as no subsystem", config, true, false},

		{"HEAD", strings.Repeat("g:", (defaultMaxSubjectLineLength/2)+1), config, true, false},

		// valid (no fixes)
		{"HEAD", "subsystem: A subject", config, false, false},
		{"HEAD", "我很好: 你好", config, false, false},
		{"HEAD", strings.Repeat("h:", (defaultMaxSubjectLineLength/2)-1), config, false, false},
		{"HEAD", strings.Repeat("i:", (defaultMaxSubjectLineLength / 2)), config, false, false},

		// valid (with fixes)
		{"HEAD", "subsystem: A subject fixes #1", config, false, true},
		{"HEAD", "subsystem: A subject fixes # 1", config, false, false},
		{"HEAD", "subsystem: A subject fixes #11", config, false, true},
		{"HEAD", "subsystem: A subject fixes #999", config, false, true},
		{"HEAD", "我很好: 你好", config, false, false},
		{"HEAD", "我很好: fixes #12345. 你好", config, false, true},
		{"HEAD", strings.Repeat("j:", (defaultMaxSubjectLineLength/2)-1), config, false, false},
		{"HEAD", strings.Repeat("k:", (defaultMaxSubjectLineLength / 2)), config, false, false},
	}

	for _, d := range data {

		if d.config != nil {
			d.config.FixesString = fixesString
			d.config.FixesPattern = fixesPattern
			d.config.FoundFixes = false
		}

		err := checkCommitSubject(d.config,
			d.commit,
			d.subject)
		if d.expectFail {
			if err == nil {
				t.Errorf("expected checkCommitSubject(%+v) to fail", d)
			}
		} else {
			if err != nil {
				t.Errorf("unexpected checkCommitSubject(%+v) failure: %v", d, err)
			}
		}

		if d.expectFixes && !d.config.FoundFixes {
			t.Errorf("Expected fixes to be found: %+v", d)
		}
	}
}

func TestCheckCommitBody(t *testing.T) {
	config := createCommitConfig()

	type testData struct {
		commit      string
		body        []string
		config      *CommitConfig
		expectFail  bool
		expectFixes bool
	}

	data := []testData{
		// invalid commit
		{"", []string{}, nil, true, false},
		{"", []string{}, nil, true, false},
		{"", []string{}, nil, true, false},
		{"", []string{}, config, true, false},
		{"", []string{}, nil, true, false},
		{"", []string{}, config, true, false},
		{"", nil, config, true, false},
		{"", []string{"", ""}, config, true, false},
		{"", []string{"", "", " "}, config, true, false},
		{"", []string{"", "", " ", ""}, config, true, false},
		{"", []string{"hello", "", "world"}, config, true, false},

		// invalid body
		{"HEAD", []string{}, nil, true, false},
		{"HEAD", []string{""}, nil, true, false},
		{"HEAD", []string{" "}, nil, true, false},
		{"HEAD", []string{" ", " ", " ", " "}, nil, true, false},
		{"HEAD", []string{"\n"}, nil, true, false},
		{"HEAD", []string{"\r"}, nil, true, false},
		{"HEAD", []string{"\r\n", " "}, nil, true, false},
		{"HEAD", []string{"\r\n", "\t"}, nil, true, false},

		{"HEAD", []string{"foo"}, nil, true, false},
		{"HEAD", []string{"foo"}, config, true, false},
		{"HEAD", []string{"foo"}, nil, true, false},
		{"HEAD", []string{"foo"}, config, true, false},
		{"HEAD", []string{"", "Signed-off-by: me@foo.com"}, config, true, false},
		{"HEAD", []string{" ", "Signed-off-by: me@foo.com"}, config, true, false},
		{"HEAD", []string{"Signed-off-by: me@foo.com"}, config, true, false},
		{"HEAD", []string{"Signed-off-by: me@foo.com", ""}, config, true, false},
		{"HEAD", []string{"Signed-off-by: me@foo.com", " "}, config, true, false},

		// SOB must be at the start of the line
		{"HEAD", []string{"foo", " Signed-off-by: me@foo.com"}, config, true, false},
		{"HEAD", []string{"foo", "  Signed-off-by: me@foo.com"}, config, true, false},
		{"HEAD", []string{"foo", "\tSigned-off-by: me@foo.com"}, config, true, false},
		{"HEAD", []string{"foo", " \tSigned-off-by: me@foo.com"}, config, true, false},
		{"HEAD", []string{"foo", "\t Signed-off-by: me@foo.com"}, config, true, false},
		{"HEAD", []string{"foo", " \t Signed-off-by: me@foo.com"}, config, true, false},

		{"HEAD", []string{strings.Repeat("l", (defaultMaxBodyLineLength)+1), "Signed-off-by: me@foo.com"}, config, true, false},

		// valid
		{"HEAD", []string{"foo", "Signed-off-by: me@foo.com"}, config, false, false},
		{"HEAD", []string{"你好", "Signed-off-by: me@foo.com"}, config, false, false},

		{"HEAD", []string{"foo", "Fixes #1", "Signed-off-by: me@foo.com"}, config, false, true},
		{"HEAD", []string{"你好", "Fixes: #1", "Signed-off-by: me@foo.com"}, config, false, true},
		{"HEAD", []string{"你好", "Fixes  # 1", "Signed-off-by: me@foo.com"}, config, false, false},
		{"HEAD", []string{"你好", "Fixes  #999", "Signed-off-by: me@foo.com"}, config, false, true},
		{"HEAD", []string{"你好", "fixes: #999", "Signed-off-by: me@foo.com"}, config, false, true},
		{"HEAD", []string{"你好", "fixes #19123", "Signed-off-by: me@foo.com"}, config, false, true},
		{"HEAD", []string{"你好", "fixes #123, #234. Fixes: #3456.", "Signed-off-by: me@foo.com"}, config, false, true},

		// SOB can be any length
		{"HEAD", []string{"foo",
			fmt.Sprintf("Signed-off-by: %s@foo.com", strings.Repeat("m", defaultMaxBodyLineLength*13))},
			config, false, false},

		// Non-alphabetic lines can be any length
		{"HEAD", []string{"foo",
			fmt.Sprintf("0%s", strings.Repeat("n", defaultMaxBodyLineLength*7)),
			fmt.Sprintf("Signed-off-by: me@foo.com")},
			config, false, false},

		{"HEAD", []string{"foo",
			fmt.Sprintf("1%s", strings.Repeat("o", defaultMaxBodyLineLength*7)),
			fmt.Sprintf("Signed-off-by: me@foo.com")},
			config, false, false},

		{"HEAD", []string{"foo",
			fmt.Sprintf("9%s", strings.Repeat("p", defaultMaxBodyLineLength*7)),
			fmt.Sprintf("Signed-off-by: me@foo.com")},
			config, false, false},

		{"HEAD", []string{"foo",
			fmt.Sprintf("_%s", strings.Repeat("q", defaultMaxBodyLineLength*7)),
			fmt.Sprintf("Signed-off-by: me@foo.com")},
			config, false, false},

		{"HEAD", []string{"foo",
			fmt.Sprintf(".%s", strings.Repeat("r", defaultMaxBodyLineLength*7)),
			fmt.Sprintf("Signed-off-by: me@foo.com")},
			config, false, false},

		{"HEAD", []string{"foo",
			fmt.Sprintf("!%s", strings.Repeat("s", defaultMaxBodyLineLength*7)),
			fmt.Sprintf("Signed-off-by: me@foo.com")},
			config, false, false},

		{"HEAD", []string{"foo",
			fmt.Sprintf("?%s", strings.Repeat("t", defaultMaxBodyLineLength*7)),
			fmt.Sprintf("Signed-off-by: me@foo.com")},
			config, false, false},

		// Indented data can be any length
		{"HEAD", []string{"foo",
			fmt.Sprintf(" %s", strings.Repeat("u", defaultMaxBodyLineLength*7)),
			fmt.Sprintf("Signed-off-by: me@foo.com")},
			config, false, false},

		{"HEAD", []string{"foo",
			fmt.Sprintf(" %s", strings.Repeat("月", defaultMaxBodyLineLength*7)),
			fmt.Sprintf("Signed-off-by: me@foo.com")},
			config, false, false},

		{"HEAD", []string{strings.Repeat("v", (defaultMaxBodyLineLength)-1), "Signed-off-by: me@foo.com"}, config, false, false},
		{"HEAD", []string{strings.Repeat("w", defaultMaxBodyLineLength), "Signed-off-by: me@foo.com"}, config, false, false},
	}

	for _, d := range data {
		if d.config != nil {
			d.config.FixesString = fixesString
			d.config.FixesPattern = fixesPattern
			d.config.FoundFixes = false
		}

		err := checkCommitBody(d.config,
			d.commit,
			d.body)
		if d.expectFail {
			if err == nil {
				t.Errorf("expected checkCommitBody(%+v) to fail", d)
			}
		} else {
			if err != nil {
				t.Errorf("unexpected checkCommitBody(%+v) failure: %v", d, err)
			}
		}

		if d.expectFixes && !d.config.FoundFixes {
			t.Errorf("Expected fixes to be found: %+v", d)
		}
	}
}
