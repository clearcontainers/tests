# release-tools

## Overview

The `release.sh` tool is used to perform the basic tag and release process
for Clear Containers . It is designed to be run after a version bump was
done in the file `VERSION` in Clear Containers repositories.

By default, it will ensure:

- A new release is greater than the last Github release.

- Won't allow create a new release with the same tag.


Optionally, the go program called `release.go` can be used to interact and
get more information about the release.

```
go build -o  release-tool
#Get last runtime version
./release-tool status runtime
#Get the next version bump for runtime repository
./release-tool status --next-bump runtime
```

### For full details

Run:

```
$ ./release-tool -h
```

## How to use it

### Download and Build

```
$ repo="github.com/clearcontainers/tests/cmd/release-tools"
$ go get -d "$repo"
$ (cd "$GOPATH/src/$repo" && make)
```

### Basic use

#### Github token

To do actions over repositories `release-tool` uses Github tokens to
generate your own token [check
here](https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/).

```
export  GITHUB_TOKEN=my_token
$ ./release.sh "$repository_name"
```


#### Change remote

Usually when working with go repositories more than one repository is
used:

- The original repository

- your own fork. 

By default, the `release.sh` script will work with the remote that points
to `clearcontainers/<repository>`. To change the remote owner export the
variable `OWNER="my_git_hub_user` and will use the remote which URL  match
`<OWNER>/<repository>`.

```
export OWNER=myuser
export GITHUB_TOKEN=my_token
./release.sh proxy
./release.sh runtime
./release.sh shim
```
