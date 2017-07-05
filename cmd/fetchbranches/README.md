# Fetch branches tool

## Overview

The `fetch branches` tool is used to perform a fetch of a branch 
locally to test and verify the changes before merging on master. 
The `fetch branches` tool is designed to run in Semaphore and it 
will only accept GitHub pull requests.
The `fetch branches` tool uses Semaphore's environment variables 
("PULL_REQUEST_NUMBER" and "SEMAPHORE_REPO_SLUG") to retrieve 
information like the pull request number and the name of the owner 
and the repository.

## Validation Tags

When raising a pull request, the commit message must have a Signed-off-by
entry. A validation tag should be part of the commit message or as a general 
comment in the pull request in order to run the `fetch branches` tool. 
The following validation tags are accepted by the `fetch branches` tool:

1. `branch_shim:URL`
2. `branch_tests:URL`
3. `branch_proxy:URL`
4. `branch_runtime:URL`
5. `branch_hyperstar:URL`

As we can see from the validation tags, after the word branch_, we 
have the name of the current repositories (shim, tests, proxy, runtime 
and hyperstart). After branch_xxx, a colon (:) is placed as a separation 
and after an URL should be placed.

The URL in the validation tags represents the URL of the branch. It should 
always start with https:// or http:// and it should be placed after branch_xxx:.

Here is an example of a validation tag:
`branch_tests:https://github.com/GabyCT/tests/tree/topic/readmefetchtool`

The `fetch branches` tool will only retrieve the comments of the author of the
pull request. The validation tag can only be replaced by the author of the pull
request. This can be done by changing the validation tag in the original commit 
message or pull request's comments. In case that the author of the pull request 
introduces two or more validation tags for the same repository (i.e. branch_tests:URL, 
branch_tests:URL2) the `fetch branches` will only consider the last validation 
tag inserted by the author of the pull request.

## Running the fetch branches tool

The `fetch branches` tool will build and run as part of the .ci/setup.sh.