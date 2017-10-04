[![Build Status](http://cc-jenkins-ci.westus2.cloudapp.azure.com/job/clear-containers-tests-azure-ubuntu-16-04-master/badge/icon)](http://cc-jenkins-ci.westus2.cloudapp.azure.com/job/clear-containers-tests-azure-ubuntu-16-04-master/)
[![Build Status](http://cc-jenkins-ci.westus2.cloudapp.azure.com/job/clear-containers-tests-azure-ubuntu-17-04-master/badge/icon)](http://cc-jenkins-ci.westus2.cloudapp.azure.com/job/clear-containers-tests-azure-ubuntu-17-04-master/)
[![Build Status](http://cc-jenkins-ci.westus2.cloudapp.azure.com/job/clear-containers-tests-fedora-26-master/badge/icon)](http://cc-jenkins-ci.westus2.cloudapp.azure.com/job/clear-containers-tests-fedora-26-master/)

# Clear Containers Tests Repository

This repository contains the test suite for the Clear Containers 3.0 project,
including functional and integration tests with Docker\*, Kubernetes\* and OpenShift\*.

A properly set up environment with Clear Containers is needed to execute
these tests. For instructions on how to setup Clear Containers, please refer to the:
[Installation Guides](https://github.com/clearcontainers/runtime/tree/master/docs)

## Functional tests

Execute:
```
	$ sudo -E PATH=$PATH make functional
```
## Docker integration tests

Execute:
```
	$ sudo -E PATH=$PATH make integration
```

## Functional and Docker integration tests

Execute:
```
	$ sudo -E PATH=$PATH make check
```

## Environment variables

By default, these tests use the version of `cc-runtime` set in the environment
variable `RUNTIME`, but you can easily change it. For example:
```
	$ RUNTIME="/usr/local/bin/cc-runtime" make functional
```
In the above example, the version of runtime installed in `/usr/local/bin` is being used.

These are the environment variables that you can change:

- `RUNTIME` - Path of Clear Containers runtime, the default path is `cc-runtime`.
- `TIMEOUT` - Time limit in seconds for each test, the default timeout is `15`.

## QA gating process

The Clear Containers project has a gating process to prevent introducing regressions.
When a patch is submitted via a pull request (PR), a continuous integration system launches
tests in different machines to ensure the change does not break current functionality.

The tests executed are:
- Functional Tests
- Integration Tests
- Docker popular images tests

If a failure is detected in any of these tests, the pull request will be blocked to prevent
it from being merged. To reproduce the failure locally, you can execute the tests on your 
environment using these [instructions](#functional-and-docker-integration-tests).

If new functionality is being added on a PR, it is recommended to at least add a basic
functional test to verify it works correctly and/or open an issue in this repository to
develop more tests for this new functionality.
