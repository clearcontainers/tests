# Copyright (c) 2017 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Path of Clear Containers Runtime
RUNTIME ?= cc-runtime

# The time limit in seconds for each test
TIMEOUT ?= 150

crio:
	bash .ci/install_bats.sh
	RUNTIME=${RUNTIME} ./integration/cri-o/cri-o.sh

ginkgo:
	ln -sf . vendor/src
	GOPATH=$(PWD)/vendor go build ./vendor/github.com/onsi/ginkgo/ginkgo
	unlink vendor/src

functional: ginkgo
	./ginkgo -v functional/ -- -runtime ${RUNTIME} -timeout ${TIMEOUT}

metrics:
	RUNTIME=${RUNTIME} ./metrics/run_all_metrics.sh

integration: ginkgo
	./ginkgo -v -focus "${FOCUS}" ./integration/docker/ -- -runtime=${RUNTIME} -timeout ${TIMEOUT}

kubernetes:
	bash -f .ci/install_bats.sh
	bash -f integration/kubernetes/run_kubernetes_tests.sh

openshift:
	bash .ci/install_bats.sh
	cd integration/openshift && \
	./init.sh && \
	bats hello_world.bats

swarm:
	bats integration/swarm/swarm.bats

conformance:
	bats conformance/posixfs/fstest.bats

check: functional crio integration conformance kubernetes

all: functional checkcommits integration

checkcommits:
	cd cmd/checkcommits && make

clean:
	cd cmd/checkcommits && make clean

.PHONY: functional check ginkgo crio metrics integration conformance kubernetes
