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
	"path/filepath"
	"reflect"
	"strconv"
	"strings"
	"sync"
	"time"
)

// Repo represents the repository under test
// For more information about this structure take a look to the README
type Repo struct {
	// URL is the url of the repository
	URL string

	// PR is the pull request number
	PR int

	// RefreshTime is the time to wait for checking if a pull request needs to be tested
	RefreshTime string

	// Toke is the repository access token
	Token string

	// Setup contains the conmmands needed to setup the environment
	Setup []string

	// Run contains the commands to run the test
	Run []string

	// Teardown contains the commands to be executed once Run ends
	Teardown []string

	// OnSuccess contains the commands to be executed if Setup, Run and Teardown finished correctly
	OnSuccess []string

	// OnFailure contains the commands to be executed if any of Setup, Run or Teardown fail
	OnFailure []string

	// PostOnSuccess is the comment to be posted if the test finished correctly
	PostOnSuccess string

	// PostOnFailure is the comment to be posted if the test fails
	PostOnFailure string

	// UseVM specify if VMs must be used to test the pull request
	UseVM bool

	// LogDir is the logs directory
	LogDir string

	// Language is the language of the repository
	Language RepoLanguage

	// CommentTrigger is the comment that must be present to trigger the test
	CommentTrigger PullRequestComment

	// LogServer contains the information of the server where the logs must be placed
	LogServer LogServer

	// Whitelist is the list of users whose pull request can be tested
	Whitelist string

	// cvr control version repository
	cvr CVR

	// refresh is RefreshTime once parsed
	refresh time.Duration

	// language is the language of the repository
	language Language

	// env contains the environment variables to be used in each stage
	env []string

	// whitelistUsers is the whitelist once parsed
	whitelistUsers []string
}

const (
	defaultLogDir      = "/var/log/localCI"
	defaultRefreshTime = "30s"
	logDirMode         = 0755
	logFileMode        = 0664
)

var defaultEnv = []string{"CI=true", "LOCALCI=true"}

var runTestsInParallel bool

var testLock sync.Mutex

func (r *Repo) setupCvr() error {
	var err error

	// validate url
	r.URL = strings.TrimSpace(r.URL)
	if len(r.URL) == 0 {
		return fmt.Errorf("missing repository url")
	}

	// get the control version repository
	r.cvr, err = newCvr(r.URL, r.Token)

	return err
}

func (r *Repo) setupLogServer() error {
	if reflect.DeepEqual(r.LogServer, LogServer{}) {
		return nil
	}

	if len(r.LogServer.IP) == 0 {
		return fmt.Errorf("missing server ip")
	}

	if len(r.LogServer.User) == 0 {
		r.LogServer.User = "root"
	}

	if len(r.LogServer.Dir) == 0 {
		r.LogServer.Dir = "/var/log/localCI"
	}

	return nil
}

func (r *Repo) setupLogDir() error {
	// validate log directory
	r.LogDir = strings.TrimSpace(r.LogDir)
	if len(r.LogDir) == 0 {
		r.LogDir = defaultLogDir
	}

	// create log directory
	if err := os.MkdirAll(r.LogDir, logDirMode); err != nil {
		return err
	}

	return nil
}

func (r *Repo) setupRefreshTime() error {
	var err error

	// set default refreshTime
	r.RefreshTime = strings.TrimSpace(r.RefreshTime)
	if len(r.RefreshTime) == 0 {
		r.RefreshTime = defaultRefreshTime
	}

	// validate refresh time
	r.refresh, err = time.ParseDuration(r.RefreshTime)
	if err != nil {
		return fmt.Errorf("failed to parse refresh time '%s' %s", r.RefreshTime, err)
	}

	return nil
}

func (r *Repo) setupCommentTrigger() error {
	if reflect.DeepEqual(r.CommentTrigger, PullRequestComment{}) {
		return nil
	}

	if len(r.CommentTrigger.Comment) == 0 {
		return fmt.Errorf("missing comment trigger")
	}

	return nil
}

// setup the repository. This method MUST BE called before use any other
func (r *Repo) setup() error {
	var err error

	setupFuncs := []func() error{
		r.setupCvr,
		r.setupRefreshTime,
		r.setupLogDir,
		r.setupLogServer,
		r.setupCommentTrigger,
		func() (err error) {
			r.language, err = r.Language.getLanguage(*r)
			return
		},
		func() error {
			if len(r.Run) == 0 {
				return fmt.Errorf("missing run commands")
			}
			return nil
		},
	}

	for _, setupFunc := range setupFuncs {
		if err = setupFunc(); err != nil {
			return err
		}
	}

	ciLog.Debugf("Using control version repository the %#v", r.cvr)

	// get the list of users
	r.whitelistUsers = append(r.whitelistUsers, "*")
	if len(r.Whitelist) != 0 {
		r.whitelistUsers = strings.Split(r.Whitelist, ",")
	}

	// add environment variables
	r.env = os.Environ()
	r.env = append(r.env, defaultEnv...)
	repoSlug := fmt.Sprintf("LOCALCI_REPO_SLUG=%s/%s", r.cvr.getOwner(), r.cvr.getRepo())
	r.env = append(r.env, repoSlug)

	return nil
}

// loop to monitor the repository
func (r *Repo) loop() {
	var err error
	var prsToTest map[string]*PullRequest
	prsTested := make(map[string]*PullRequest)

	ciLog.Debugf("monitoring in a loop the repository %#v", r)

	for {
		// if PR is not 0 then we have to monitor just one PR
		if r.PR != 0 {
			prsToTest = make(map[string]*PullRequest)
			var pr *PullRequest
			ciLog.Debugf("requesting single PR %#v", r.PR)
			pr, err = r.cvr.getPullRequest(r.PR)
			prsToTest[strconv.Itoa(r.PR)] = pr
		} else {
			ciLog.Debug("requesting list of PRs")
			prsToTest, err = r.cvr.getOpenPullRequests()
		}

		if err != nil {
			ciLog.Errorf("failed to get pull requests: %s", err)
			goto sleep
		}

		ciLog.Debugf("got %d PRs to process", len(prsToTest))

		for number, prToTest := range prsToTest {
			ciLog.Debugf("checking pr %+v", prToTest)
			prTested := prsTested[number]
			if prTested != nil {
				if prToTest.Equal(*prTested) {
					ciLog.Debugf("pr %+v was already tested", prToTest)
					goto sleep
				}
				// checking if the old version of the PR is being tested
				if prTested.BeingTested {
					ciLog.Debugf("pr %+v is being tested", prTested)
					goto sleep
				}
			}

			if err := r.testPullRequest(prToTest); err != nil {
				ciLog.Errorf("failed to test pull request %+v: %s", prToTest, err)
				goto sleep
			}

			// copy the PR that was tested
			// FIXME: remove the PR's that were closed or merged
			prsTested[number] = prToTest
		}

	sleep:
		ciLog.Debugf("napping for %s", r.RefreshTime)
		time.Sleep(r.refresh)
	}
}

// test the pull request specified in the configuration file
// if pr does not exist an error is returned
func (r *Repo) test() error {
	ciLog.Debugf("testing the repository %+v", r)

	if r.PR == 0 {
		return fmt.Errorf("Missing pull request number in configuration file")
	}

	pr, err := r.cvr.getPullRequest(r.PR)
	if err != nil {
		return fmt.Errorf("failed to get pull request %d %s", r.PR, err)
	}

	// run tests in parallel does not make sense when
	// we are just testing one pull request
	runTestsInParallel = false

	return r.testPullRequest(pr)
}

// testPullRequest tests a specific pull request.
// returns an error if the test fail
func (r *Repo) testPullRequest(pr *PullRequest) error {
	var err error

	ciLog.Debugf("testing PR %+v", pr)
	// before check if the PR can be tested we have to set the
	// comment trigger
	if len(r.CommentTrigger.Comment) != 0 {
		pr.CommentTrigger, err = r.cvr.getLatestPullRequestComment(pr.Number, r.CommentTrigger)
		if err != nil {
			reterr := fmt.Errorf("missing comment trigger in pull request %s", err)
			ciLog.Debugf(reterr.Error())
			return reterr
		}
	}

	// check if the PR can be tested
	if err = pr.canBeTested(); err != nil {
		return err
	}

	if strings.Compare(r.whitelistUsers[0], "@") == 0 {
		found, err := r.cvr.isMember(pr.Author)
		if err != nil {
			return fmt.Errorf("unable to determinate if user '%s' is a member of the organization %s", pr.Author, err)
		}

		if !found {
			return fmt.Errorf("user '%s' is not a member of the organization", pr.Author)
		}
	} else if strings.Compare(r.whitelistUsers[0], "*") != 0 {
		found := false
		for _, u := range r.whitelistUsers {
			if strings.Compare(u, pr.Author) == 0 {
				found = true
				break
			}
		}

		if !found {
			return fmt.Errorf("user '%s' is not part of the whitelist", pr.Author)
		}
	}

	if !runTestsInParallel {
		testLock.Lock()
		defer testLock.Unlock()
	}

	if r.UseVM {
		return r.testPROnVM(pr)
	}

	// change the pr state before start the test
	pr.BeingTested = true

	testFunc := func() error {
		err := r.runTest(pr)
		pr.BeingTested = false
		return err
	}

	if !runTestsInParallel {
		return testFunc()
	}

	go func() {
		err := testFunc()
		if err != nil {
			ciLog.Errorf("failed to test pull request %+v: %s", *pr, err)
		}
	}()

	return nil
}

func (r *Repo) testPROnVM(pr *PullRequest) error {
	//FIXME: This function has to:
	// - start a VM
	// - install localCI
	// - create a configuration file to test a specific PR
	// - run localCI as workload
	//FIXME: Install go before spawn the VM

	if runTestsInParallel {
		//FIXME: setup and spawn a VM using a goroutine
		return nil
	}

	//FIXME: setup and spawn VM and wait
	//FIXME: set pr.BeingTested
	//FIXME: add WaitGroup
	return nil
}

// Steps to test a pull request:
// - setup the project language
// - download the pull request
// - run stages (setup, run and teardown)
// - if any stage fails then 'PostOnFailure' and run 'onFailure' commands
// - if all is ok 'postOnSuccess' and run 'onSuccess' commands
// - teardown the project language
// - remove working directory
// - copy logs to the server
func (r *Repo) runTest(pr *PullRequest) error {
	var err error

	// setup the language
	ciLog.Debugf("setting up language: %+v", r.language)
	if err = r.language.setup(); err != nil {
		return err
	}
	defer func() {
		err = r.language.teardown()
		if err != nil {
			ciLog.Errorf("failed to teardown the language: %s", err)
		}
	}()

	// clone the project
	ciLog.Debugf("downloading pull request: %+v", pr)
	pr.WorkingDir, err = r.cvr.downloadPullRequest(*pr, r.language.getCloneDir())
	if err != nil {
		return err
	}
	defer func() {
		err = os.RemoveAll(pr.WorkingDir)
		if err != nil {
			ciLog.Errorf("failed to remove the working directory '%s': %s", pr.WorkingDir, err)
		}
	}()

	// cleanup and set the log directory of the pull request
	pr.LogDir = filepath.Join(r.LogDir, strconv.Itoa(pr.Number))
	_ = os.RemoveAll(pr.LogDir)
	if err = os.MkdirAll(pr.LogDir, logDirMode); err != nil {
		return err
	}

	// set environment variables
	pr.Env = r.env

	// appends language environment variables
	langEnv := r.language.getEnv()
	if len(langEnv) > 0 {
		pr.Env = append(pr.Env, langEnv...)
	}

	// appends other environment variables
	prNumber := fmt.Sprintf("LOCALCI_PR_NUMBER=%d", pr.Number)
	pr.Env = append(pr.Env, prNumber)

	// copy logs to server if we have an IP address
	if len(r.LogServer.IP) != 0 {
		defer func() {
			err = r.LogServer.copy(pr.LogDir)
			if err != nil {
				ciLog.Errorf("failed to copy log dir %s to server %+v", pr.LogDir, r.LogServer)
			}
		}()
	}

	// run stages
	return r.runStages(pr)
}

func (r *Repo) runStages(pr *PullRequest) error {
	var err error

	stages := []struct {
		name     string
		commands []string
	}{
		{name: "setup", commands: r.Setup},
		{name: "run", commands: r.Run},
		{name: "teardown", commands: r.Teardown},
	}

	ciLog.Debugf("testing pull request: %+v", pr)

	for _, s := range stages {
		if len(s.commands) == 0 {
			ciLog.Debugf("there are not commands for the stage '%s'", s.name)
			continue
		}

		ciLog.Debugf("running stage %+v", s)

		if err = pr.runStage(s.name, s.commands); err != nil {
			ciLog.Errorf("failed to run stage '%s': %s", s.name, err)
			if len(r.PostOnFailure) != 0 {
				if err = r.cvr.createComment(pr.Number, r.PostOnFailure); err != nil {
					ciLog.Errorf("failed to create comment '%s' on pull request %d", r.PostOnFailure, pr.Number)
				}
			}

			if e := pr.runStage("onFailure", r.OnFailure); e != nil {
				ciLog.Errorf("faile to run 'onFailure' stage: %s", err)
			}

			return err
		}
	}

	// check if there are commands to run onSuccess
	if len(r.OnSuccess) != 0 {
		defer func() {
			// run 'onSuccess' stage
			if err := pr.runStage("onSuccess", r.OnSuccess); err != nil {
				ciLog.Errorf("failed to run 'onSuccess' stage: %s", err)
			}
		}()
	}

	// check if there is a comment to create on success
	if len(r.PostOnSuccess) != 0 {
		err = r.cvr.createComment(pr.Number, r.PostOnSuccess)
		if err != nil {
			return fmt.Errorf("failed to create comment in pull request %d %s", pr.Number, err)
		}
	}

	return nil
}
