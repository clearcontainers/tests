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
	"sync"

	"github.com/Sirupsen/logrus"
	"github.com/urfave/cli"
)

// name is the name of the program.
const name = "localCI"

// usage is the usage of the program.
const usage = name + ` is a continuous integration system`

var ciLog = logrus.New()

func loop(repos []Repo) error {
	var wg sync.WaitGroup

	for _, r := range repos {
		if err := r.setup(); err != nil {
			ciLog.Errorf("failed to initialize repository: %s", err)
			continue
		}

		wg.Add(1)
		go func(repo Repo) {
			repo.loop()
			wg.Done()
		}(r)
	}

	wg.Wait()

	return nil
}

func testRepos(repos []Repo) error {
	for _, r := range repos {
		if err := r.setup(); err != nil {
			ciLog.Errorf("failed to initialize repository: %s", err)
			continue
		}

		if err := r.test(); err != nil {
			ciLog.Errorf("failed to test repo %+v: %s", r, err)
			return err
		}
	}

	return nil
}

func main() {
	app := cli.NewApp()
	app.Name = name
	app.Usage = usage
	app.Version = fmt.Sprintf("localCI : %s\nCommit  : %s", version, commit)

	// Override the default function to display version details to
	// ensure the "--version" option and "version" command are identical.
	cli.VersionPrinter = func(c *cli.Context) {
		fmt.Println(c.App.Version)
	}

	app.Flags = []cli.Flag{
		cli.StringFlag{
			Name:  "config",
			Usage: "configuration file path",
		},
		cli.BoolFlag{
			Name:  "daemon",
			Usage: "run " + name + " as a daemon monitoring the repositories specified in the configuration file",
		},
		cli.BoolFlag{
			Name:  "debug",
			Usage: "enable debug output for logging",
		},
		cli.StringFlag{
			Name:  "log",
			Value: "/dev/null",
			Usage: "set the log file path where internal debug information is written",
		},
	}

	app.Before = func(context *cli.Context) error {
		var err error

		if context.GlobalBool("debug") {
			ciLog.Level = logrus.DebugLevel
		}

		if path := context.GlobalString("log"); path != "" {
			f, err := os.OpenFile(path, os.O_CREATE|os.O_WRONLY|os.O_APPEND|os.O_SYNC, 0640)
			if err != nil {
				return err
			}
			ciLog.Out = f
		}

		config, err := newConfig(context.GlobalString("config"))
		if err != nil {
			return err
		}
		ciLog.Debugf("configuration %+v", config)

		runTestsInParallel = config.RunTestsInParallel

		context.App.Metadata = map[string]interface{}{
			"repos": config.Repo,
		}

		return nil
	}

	app.Action = func(context *cli.Context) error {
		repos := context.App.Metadata["repos"].([]Repo)

		if len(repos) == 0 {
			ciLog.Info("There are no repos to monitor or test")
			return nil
		}

		if context.GlobalBool("daemon") {
			return loop(repos)
		}
		return testRepos(repos)
	}

	if err := app.Run(os.Args); err != nil {
		ciLog.Error(err)
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
