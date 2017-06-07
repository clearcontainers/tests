# Path of Clear Containers Runtime
CC_RUNTIME ?= cc-runtime

# The time limit in seconds for each test
TIMEOUT ?= 5

ginkgo:
	ln -sf . vendor/src
	GOPATH=$(PWD)/vendor go build ./vendor/github.com/onsi/ginkgo/ginkgo
	unlink vendor/src

functional: ginkgo
	./ginkgo functional/ -- -runtime ${CC_RUNTIME} -timeout ${TIMEOUT}

check:	functional

all: functional checkcommits

checkcommits:
	cd cmd/checkcommits && make

clean:
	cd cmd/checkcommits && make clean

.PHONY: functional check ginkgo
