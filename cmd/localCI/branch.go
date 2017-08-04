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

	"github.com/Sirupsen/logrus"
)

type repoBranch struct {
	// info contains information of the branch
	info repoBranchInfo

	// name of the branch
	name string

	// cvr is the control version repository
	cvr CVR

	// beingTested is true when the branch is being tested
	beingTested bool

	// logger of the branch
	logger *logrus.Entry
}

// newRepoBranch returns new branch
func newRepoBranch(branchName string, cvr CVR, logger *logrus.Entry) (*repoBranch, error) {
	i, err := cvr.getBranchInfo(branchName)
	if err != nil {
		return nil, fmt.Errorf("failed to get branch info %s", err)
	}

	return &repoBranch{
		info:        i,
		name:        branchName,
		cvr:         cvr,
		beingTested: false,
		logger:      logger,
	}, nil
}

func (b *repoBranch) canBeTested() error {
	// branch can be tested always
	return nil
}

func (b *repoBranch) download(path string) error {
	b.logger.Debugf("downloading branch %s", b.name)

	return b.cvr.downloadBranch(b.name, path)
}

func (b *repoBranch) isBeingTested() bool {
	return b.beingTested
}

func (b *repoBranch) id() string {
	return b.name
}

func (b *repoBranch) equal(r interface{}) bool {
	rb, ok := r.(*repoBranch)
	if !ok {
		return false
	}

	if b.name != rb.name {
		return false
	}

	if b.info.sha != rb.info.sha {
		return false
	}

	return true
}

func (b *repoBranch) test(config stageConfig, stages map[string]stage) error {
	var err error
	b.beingTested = true

	config.logger.Debugf("testing branch: %+v", *b)

	runStage := func(stage string) error {
		s, ok := stages[stage]
		if ok {
			return s.run(config)
		}
		return nil
	}

	defer func() {
		// run 'teardown' stage
		if e := runStage("teardown"); e != nil {
			// do not override err if it already has a error
			if err == nil {
				err = e
			}
		}

		stage := "onSuccess"
		if err != nil {
			stage = "onFailure"
		}

		e := runStage(stage)
		if e != nil {
			config.logger.Errorf("failed to run %s stage: %s", stage, e)
		}

		b.beingTested = false
	}()

	envars := []string{"LOCALCI_BRANCH_NAME=" + b.name}
	config.env = append(config.env, envars...)

	// run 'setup' stage
	if err = runStage("setup"); err != nil {
		return err
	}

	// run 'run' stage
	if err = runStage("run"); err != nil {
		return err
	}

	return err
}

func (b *repoBranch) logDirName() string {
	return b.info.sha
}
