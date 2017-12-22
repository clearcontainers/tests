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

	"github.com/urfave/cli"
)

var releaseCommand = cli.Command{
	Name:  "release",
	Usage: "Create a Clear Containers release",
	Flags: []cli.Flag{
		cli.StringFlag{
			Name:  "version",
			Usage: "Use version defined by this flag, otherwise the version will do a version bump x.y.z to x.y.(x+1)",
		},
		cli.StringSliceFlag{
			Name:  "asset",
			Usage: "asset to upload",
			Value: &cli.StringSlice{},
		},
		cli.StringFlag{
			Name:  "commit",
			Usage: "commit or branch to use to create tag",
			Value: "master",
		},
		cli.StringFlag{
			Name:  "notes",
			Usage: "Release notes",
			Value: "",
		},
	},
	Before: func(c *cli.Context) error {
		if c.NArg() < 1 {
			return fmt.Errorf("repository is mandatory")
		}
		return nil
	},
	Action: func(c *cli.Context) error {

		fmt.Println("Creating new version")
		token := c.GlobalString("token")
		if token == "" {
			return fmt.Errorf("Token is empty, you need a token to do a release")
		}
		gh, err := newGitHubClient(c.GlobalString("owner"), token)
		if err != nil {
			return err
		}

		assets := c.StringSlice("asset")

		if err := gh.createRelease(c.Args().First(), c.String("commit"), c.String("version"), c.String("notes"), assets); err != nil {
			return err
		}

		return nil
	},
}

var statusCommand = cli.Command{
	Name:  "status",
	Usage: "Get release status",
	Flags: []cli.Flag{
		cli.BoolFlag{
			Name:  "next-bump",
			Usage: "Show next version bump for a repository",
		},
	},
	Before: func(c *cli.Context) error {
		if c.NArg() < 1 {
			return fmt.Errorf("repository is mandatory")
		}
		return nil
	},
	Action: func(c *cli.Context) error {
		gh, err := newGitHubClient(c.GlobalString("owner"), c.GlobalString("token"))
		if err != nil {
			return err
		}
		repo := c.Args().First()
		version, err := gh.getLatestRelease(c.Args().First())
		if err != nil {
			return err
		}

		if c.Bool("next-bump") {
			bump, err := nextBump(version)
			if err != nil {
				return err
			}
			fmt.Println(bump)
			return nil
		}

		fmt.Println("Repository: ", gh.owner, "/", repo)
		fmt.Println("Version: ", version)

		return nil
	},
}
var globalFlags = []cli.Flag{
	cli.StringFlag{
		Name:   "owner",
		Value:  "clearcontainers",
		Usage:  "Repository onwer",
		EnvVar: "GITHUB_OWNER",
	},
	cli.StringFlag{
		Name:   "token",
		Value:  "",
		Usage:  "Github token",
		EnvVar: "GITHUB_TOKEN",
	},
}

func main() {
	app := cli.NewApp()
	app.Flags = globalFlags
	app.Before = func(c *cli.Context) error {
		if c.String("owner") == "" {
			return fmt.Errorf("Owner can not be emtpy")
		}
		return nil
	}
	app.Commands = []cli.Command{
		releaseCommand,
		statusCommand,
	}

	if err := app.Run(os.Args); err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
	}
}
