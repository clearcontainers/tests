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
	"os"
	"regexp"
	"strings"
	"testing"
)

// An environment variable value. If set is true, set it,
// else unset it (ignoring the value).
type TestEnvVal struct {
	value string
	set   bool
}

type TestCIEnvData struct {
	name              string
	env               map[string]TestEnvVal
	expectedCommit    string
	expectedSrcBranch string
	expectedDstBranch string
}

var fixesString string
var fixesPattern *regexp.Regexp

// List of variables to restore after the tests have run
var restoreSet map[string]TestEnvVal

var travisPREnv = map[string]TestEnvVal{
	"TRAVIS":                     TestEnvVal{"true", true},
	"TRAVIS_BRANCH":              TestEnvVal{"master", true},
	"TRAVIS_COMMIT":              TestEnvVal{"travis-commit", true},
	"TRAVIS_PULL_REQUEST_BRANCH": TestEnvVal{"travis-pr", true},
}

var travisNonPREnv = map[string]TestEnvVal{
	"TRAVIS":                     TestEnvVal{"true", true},
	"TRAVIS_BRANCH":              TestEnvVal{"master", true},
	"TRAVIS_COMMIT":              TestEnvVal{"travis-commit", true},
	"TRAVIS_PULL_REQUEST_BRANCH": TestEnvVal{"", true},
}

var semaphorePREnv = map[string]TestEnvVal{
	"SEMAPHORE":           TestEnvVal{"true", true},
	"BRANCH_NAME":         TestEnvVal{"semaphore-pr", true},
	"REVISION":            TestEnvVal{"semaphore-commit", true},
	"PULL_REQUEST_NUMBER": TestEnvVal{"semaphore-pr", true},
}

var semaphoreNonPREnv = map[string]TestEnvVal{
	"SEMAPHORE":   TestEnvVal{"true", true},
	"BRANCH_NAME": TestEnvVal{"master", true},
	"REVISION":    TestEnvVal{"semaphore-commit", true},

	// XXX: the odd one out - unset it
	"PULL_REQUEST_NUMBER": TestEnvVal{"", false},
}

var testCIEnvData = []TestCIEnvData{
	{
		name:              "TravisCI PR branch",
		env:               travisPREnv,
		expectedCommit:    travisPREnv["TRAVIS_COMMIT"].value,
		expectedSrcBranch: travisPREnv["TRAVIS_PULL_REQUEST_BRANCH"].value,
		expectedDstBranch: travisPREnv["TRAVIS_BRANCH"].value,
	},
	{
		name:              "TravisCI non-PR branch",
		env:               travisNonPREnv,
		expectedCommit:    travisNonPREnv["TRAVIS_COMMIT"].value,
		expectedSrcBranch: travisNonPREnv["TRAVIS_PULL_REQUEST_BRANCH"].value,
		expectedDstBranch: travisNonPREnv["TRAVIS_BRANCH"].value,
	},
	{
		name:              "SemaphoreCI PR branch",
		env:               semaphorePREnv,
		expectedCommit:    semaphorePREnv["REVISION"].value,
		expectedSrcBranch: semaphorePREnv["BRANCH_NAME"].value,
		expectedDstBranch: "origin",
	},
	{
		name:              "SemaphoreCI non-PR branch",
		env:               semaphoreNonPREnv,
		expectedCommit:    semaphoreNonPREnv["REVISION"].value,
		expectedSrcBranch: "",
		expectedDstBranch: semaphoreNonPREnv["BRANCH_NAME"].value,
	},
}

func init() {
	fixesString = "Fixes"
	fixesPattern = regexp.MustCompile(fmt.Sprintf("(?i)%s:* *#\\d+", fixesString))

	saveEnv()
}

func createCommitConfig() (config *CommitConfig) {
	return NewCommitConfig(true, true,
		fixesString,
		"Signed-off-by",
		defaultMaxBodyLineLength,
		defaultMaxSubjectLineLength)
}

// Save the existing values of all variables that the tests will
// manipulate. These can be restored at the end of the tests by calling
// restoreEnv().
func saveEnv() {
	// Unique list of variables the tests manipulate
	varNames := make(map[string]int)
	restoreSet = make(map[string]TestEnvVal)

	for _, d := range testCIEnvData {
		for k, _ := range d.env {
			varNames[k] = 1
		}
	}

	for key, _ := range varNames {
		// Determine if the variable is already set
		value, set := os.LookupEnv(key)
		restoreSet[key] = TestEnvVal{value, set}
	}
}

// Apply the set of variables saved by a call to saveEnv() to the
// environment.
func restoreEnv() {
	for key, envVal := range restoreSet {
		var err error
		if envVal.set {
			err = os.Setenv(key, envVal.value)
		} else {
			err = os.Unsetenv(key)
		}

		if err != nil {
			panic(err)
		}
	}
}

// Apply a list of CI variables to the current environment. This will
// involve either setting or unsetting variables.
func setCIVariables(env map[string]TestEnvVal) (err error) {
	for key, envVal := range env {

		if envVal.set {
			err = os.Setenv(key, envVal.value)
		} else {
			err = os.Unsetenv(key)
		}

		if err != nil {
			return err
		}
	}

	return nil
}

// XXX: This function *MUST* unset all variables for all supported CI
// systems.
//
// XXX: Call saveEnv() prior to calling this function.
func clearCIVariables() {
	envVars := []string{
		"TRAVIS",
		"TRAVIS_BRANCH",
		"TRAVIS_COMMIT",
		"TRAVIS_PULL_REQUEST_BRANCH",

		"SEMAPHORE",
		"REVISION",
		"BRANCH_NAME",
		"PULL_REQUEST_NUMBER",
	}

	for _, envVar := range envVars {
		os.Unsetenv(envVar)
	}
}

// Undo the effects of setCIVariables().
func unsetCIVariables(env map[string]TestEnvVal) (err error) {
	for key, _ := range env {
		err := os.Unsetenv(key)
		if err != nil {
			return err
		}
	}

	return nil
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

	// Simulate a Travis build on the "master" branch
	config.NeedFixes = true
	config.NeedSOBS = true
	err = checkCommits(config, []string{})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
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

		// valid

		// single-word long lines should be accepted
		{"HEAD", []string{strings.Repeat("l", (defaultMaxBodyLineLength)+1), "Signed-off-by: me@foo.com"}, config, false, false},
		{"HEAD", []string{"https://this-is-a-really-really-really-reeeeally-loooooooong-and-silly-unique-resource-locator-that-nobody-should-ever-have-to-type/27706e53e877987138d758bcfcac6af623059be7/yet-another-silly-long-file-name-foo.html", "Signed-off-by: me@foo.com"}, config, false, false},
		// indented URL
		{"HEAD", []string{" https://this-is-a-really-really-really-reeeeally-loooooooong-and-silly-unique-resource-locator-that-nobody-should-ever-have-to-type/27706e53e877987138d758bcfcac6af623059be7/yet-another-silly-long-file-name-foo.html", "Signed-off-by: me@foo.com"}, config, false, false},

		// multi-word long lines should not be accepted
		{"HEAD", []string{
			fmt.Sprintf("%s %s",
				strings.Repeat("l", (defaultMaxBodyLineLength/2)+1),
				strings.Repeat("l", (defaultMaxBodyLineLength/2)+1),
			),
			"Signed-off-by: me@foo.com"}, config, false, false},

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

func TestIgnoreSrcBranch(t *testing.T) {
	type testData struct {
		commit           string
		srcBranch        string
		branchesToIgnore []string
		expected         string
	}

	data := []testData{
		{"", "", nil, ""},
		{"", "", []string{}, ""},
		{"commit", "", []string{}, ""},
		{"commit", "", []string{""}, ""},
		{"commit", "", []string{"", ""}, ""},
		{"commit", "branch", []string{}, ""},
		{"commit", "branch", []string{""}, ""},
		{"commit", "branch", []string{"branch"}, "branch"},
		{"commit", "branch", []string{"b.*"}, "b.*"},
		{"commit", "branch", []string{"^b.*h$"}, "^b.*h$"},
	}

	for _, d := range data {
		result := ignoreSrcBranch(d.commit, d.srcBranch, d.branchesToIgnore)
		if result != d.expected {
			t.Fatalf("Unexpected ignoreSrcBranch return value %v (params %+v)", result, d)
		}
	}
}

func TestDetectCIEnvironment(t *testing.T) {
	for _, d := range testCIEnvData {
		err := setCIVariables(d.env)
		if err != nil {
			t.Fatal(err)
		}

		commit, dstBranch, srcBranch := detectCIEnvironment()

		if commit != d.expectedCommit {
			t.Fatalf("Unexpected commit %v (%+v)", commit, d)
		}

		if dstBranch != d.expectedDstBranch {
			t.Fatalf("Unexpected destination branch %v (%+v)", dstBranch, d)
		}

		if srcBranch != d.expectedSrcBranch {
			t.Fatalf("Unexpected source branch %v (%+v)", srcBranch, d)
		}

		// Crudely undo the changes (it'll be fully undone later
		// using restoreEnv() but this is required to avoid
		// tests interfering with one another).
		err = unsetCIVariables(d.env)
		if err != nil {
			t.Fatal(err)
		}
	}

	restoreEnv()
}

func TestGetCommitAndBranch(t *testing.T) {
	clearCIVariables()

	type testData struct {
		args                []string
		srcBranchesToIgnore []string
		expectedCommit      string
		expectedBranch      string
		expectFail          bool
	}

	data := []testData{
		{nil, nil, "", "", true},
		{[]string{}, nil, "", "", true},
		{nil, []string{}, "", "", true},
		{[]string{}, []string{}, "HEAD", "master", false},
		{[]string{"commit"}, []string{}, "commit", "master", false},
		{[]string{"commit", "branch"}, []string{}, "commit", "branch", false},
		{[]string{"too", "many", "args"}, []string{}, "commit", "branch", true},
	}

	for _, d := range data {
		commit, branch, err := getCommitAndBranch(d.args, d.srcBranchesToIgnore)

		if d.expectFail {
			if err == nil {
				t.Fatalf("Unexpected success: %+d", d)
			}
		} else {
			if err != nil {
				t.Fatalf("Unexpected failure: %+d: %v", d, err)
			}
		}

		if d.expectFail {
			continue
		}

		if commit != d.expectedCommit {
			t.Fatalf("Unexpected commit %v (%+v)", commit, d)
		}

		if branch != d.expectedBranch {
			t.Fatalf("Expected branch %v, got %v", d.expectedBranch, branch)
		}
	}

	// Now deal with CI auto-detection
	for _, d := range testCIEnvData {
		err := setCIVariables(d.env)
		if err != nil {
			t.Fatal(err)
		}

		// XXX: crucially, no arguments (to trigger the auto-detection)
		commit, dstBranch, err := getCommitAndBranch([]string{}, []string{})

		if commit != d.expectedCommit {
			t.Fatalf("Unexpected commit %v (%+v)", commit, d)
		}

		if dstBranch != d.expectedDstBranch {
			t.Fatalf("Unexpected destination branch %v (%+v)", dstBranch, d)
		}

		// Crudely undo the changes (it'll be fully undone later
		// using restoreEnv() but this is required to avoid
		// tests interfering with one another).
		err = unsetCIVariables(d.env)
		if err != nil {
			t.Fatal(err)
		}
	}

	restoreEnv()
}
