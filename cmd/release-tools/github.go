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
	"context"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"time"

	"github.com/blang/semver"
	"github.com/google/go-github/github"
	"golang.org/x/oauth2"
	"golang.org/x/sys/unix"
)

const (
	timeoutShortRequest = 5 * time.Second
)

type GitHubClient struct {
	owner string
	github.Client
}

func newGitHubClient(owner string, token string) (*GitHubClient, error) {
	ctx := context.Background()

	var tc *http.Client

	if token != "" {
		ts := oauth2.StaticTokenSource(
			&oauth2.Token{AccessToken: token},
		)
		tc = oauth2.NewClient(ctx, ts)
	}

	return &GitHubClient{owner, *github.NewClient(tc)}, nil
}

func nextBump(v string) (semver.Version, error) {
	versionBump, err := semver.Make(v)
	if err != nil {
		return versionBump, err
	}
	versionBump.Patch++
	return versionBump, nil
}

func checkAssets(assets []string) error {
	for _, asset := range assets {
		fmt.Println("Checking file", asset)
		st, err := os.Stat(asset)
		if err != nil {
			return err
		}

		mode := st.Mode()
		fmt.Printf("is a regular file... ")
		if !mode.IsRegular() {
			fmt.Println("FAIL")
			return fmt.Errorf("Not a regular file")
		}
		fmt.Println("OK")

		fmt.Printf("has read permissions ...")
		if unix.Access(asset, unix.W_OK) != nil {
			fmt.Println("FAIL")
			return err
		}
		fmt.Println("OK")
	}
	return nil
}
func (c *GitHubClient) uploadAsset(repo string, releaseID int, asset string) error {

	ctx, cancel := context.WithTimeout(context.Background(), timeoutShortRequest)
	defer cancel()

	f, err := os.Open(asset)
	if err != nil {
		return err
	}
	defer f.Close()

	opts := &github.UploadOptions{
		Name: filepath.Base(asset),
	}

	_, _, err = c.GetRepositories().UploadReleaseAsset(ctx, c.owner, repo, releaseID, opts, f)

	if err != nil {
		return err
	}
	return nil
}

// If tag is empty will do a version bump
func (c *GitHubClient) createRelease(repo string, commit string, tag string, notes string, assets []string) error {

	latestRelease, err := c.getLatestRelease(repo)
	if err != nil {
		return err
	}

	latestVersion, err := semver.Make(latestRelease)
	if err != nil {
		return err
	}

	err = checkAssets(assets)
	if err != nil {
		return err
	}

	fmt.Println("Latest release:", latestRelease)

	if tag == "" {
		fmt.Println("tag/version is empty doing format bump")
		bump, err := nextBump(latestRelease)
		if err != nil {
			return err
		}
		tag = bump.String()
	}

	fmt.Println("New version: ", tag)
	newVersion, err := semver.Make(tag)
	if err != nil {
		return err
	}

	if !newVersion.GT(latestVersion) {
		return fmt.Errorf("version %s is not greater than %s", newVersion, latestVersion)
	}

	r := new(github.RepositoryRelease)
	//"tag_name": "v1.0.0",
	r.TagName = &tag
	//"target_commitish": "master",
	r.TargetCommitish = &commit
	//"name": "v1.0.0",
	releaseName := "Release:" + tag
	r.Name = &releaseName
	//"body": "Description of the release",
	r.Body = &notes
	//"draft": false,
	draft := false
	r.Draft = &draft
	//"prerelease": false
	prerelease := false
	r.Prerelease = &prerelease

	ctx, cancel := context.WithTimeout(context.Background(), timeoutShortRequest)
	defer cancel()
	release, resp, err := c.GetRepositories().CreateRelease(ctx, c.owner, repo, r)

	if err != nil {
		fmt.Println(resp)
		return err
	}

	for _, asset := range assets {
		if err := c.uploadAsset(repo, *release.ID, asset); err != nil {
			return err
		}
	}

	fmt.Println("New release ", *release.TagName, " was created")

	return nil
}

func (c *GitHubClient) getLatestRelease(repo string) (string, error) {

	ctx, cancel := context.WithTimeout(context.Background(), timeoutShortRequest)
	defer cancel()

	release, _, err := c.GetRepositories().GetLatestRelease(ctx,
		c.owner, repo)

	if err != nil {
		return "", err
	}

	return release.GetTagName(), nil
}
