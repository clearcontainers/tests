Tests
=====

Clear Containers Tests Repository

Functional tests
----------------

In order to run all functional test you have to install next packages

- github.com/onsi/ginkgo/ginkgo
- github.com/onsi/gomega

To install above packages, just run::

  $ go get github.com/onsi/ginkgo/ginkgo
  $ go get github.com/onsi/gomega

and add ``$GOPATH/bin`` to the ``$PATH``::

  $ export GOBIN=$GOPATH/bin
  $ export PATH=$PATH:$GOBIN

To run all functional tests, run::

  $ make functional

`Environment variables`_ can be used to override the paths of Clear Containers components.
For example::

  $ RUNTIME="cc-runtime" make functional

in the above example the installed version of the Runtime is used


Environment variables
---------------------

- `RUNTIME` - Path of Clear Containers Runtime, the default path is ``$GOPATH/src/github.com/clearcontainers/runtime/cc-runtime``
- `PROXY` - Path of Clear Containers Proxy, the default path is ``$GOPATH/src/github.com/clearcontainers/proxy/cc-proxy``
- `SHIM` - Path of Clear Containers Shim, the default path is ``$GOPATH/src/github.com/clearcontainers/shim/cc-shim``
- `TIMEOUT` - Time limit in seconds for each test, the default timeout is ``5``
