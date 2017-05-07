# Path of Clear Containers Runtime
RUNTIME ?= "${GOPATH}/src/github.com/clearcontainers/runtime/cc-runtime"

# Path of Clear Containers Proxy
PROXY ?= "${GOPATH}/src/github.com/clearcontainers/proxy/cc-proxy"

# Path of Clear Containers Shim
SHIM ?= "${GOPATH}/src/github.com/clearcontainers/shim/cc-shim"

# The time limit in seconds for each test
TIMEOUT ?= 5

functional:
	ginkgo ./functional/ -- -runtime "${RUNTIME}" -proxy "${PROXY}" -shim "${SHIM}" -timeout ${TIMEOUT}

check:
	.ci/go-lint.sh

all: functional

.PHONY: functional check
