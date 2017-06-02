# Path of Clear Containers Runtime
RUNTIME ?= "${GOPATH}/src/github.com/clearcontainers/runtime/cc-runtime"

# Path of Clear Containers Proxy
PROXY ?= "${GOPATH}/src/github.com/clearcontainers/proxy/cc-proxy"

# Path of Clear Containers Shim
SHIM ?= "${GOPATH}/src/github.com/clearcontainers/shim/cc-shim"

# The time limit in seconds for each test
TIMEOUT ?= 5

TESTS_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

GINKGO_PATH = ${GOPATH}/bin/ginkgo

ginkgo:
	go get github.com/onsi/ginkgo/ginkgo

functional: ginkgo
	$(GINKGO_PATH) $(TESTS_DIR)/functional/ -- -runtime "${RUNTIME}" -proxy "${PROXY}" -shim "${SHIM}" -timeout ${TIMEOUT}

check:	functional

all: functional checkcommits

checkcommits:
	cd cmd/checkcommits && make

clean:
	cd cmd/checkcommits && make clean

.PHONY: functional check ginkgo
