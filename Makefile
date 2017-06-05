# Path of Clear Containers Runtime
CC_RUNTIME ?= cc-runtime

# The time limit in seconds for each test
TIMEOUT ?= 5

GINKGO_PATH = ${GOPATH}/bin/ginkgo

ginkgo:
	go get github.com/onsi/ginkgo/ginkgo

functional: ginkgo
	$(GINKGO_PATH) functional/ -- -runtime ${CC_RUNTIME} -timeout ${TIMEOUT}

check:
	.ci/go-lint.sh

all: functional checkcommits

checkcommits:
	cd cmd/checkcommits && make

clean:
	cd cmd/checkcommits && make clean

.PHONY: functional check ginkgo
