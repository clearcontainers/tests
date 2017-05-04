Tests
=====

Clear Containers Tests Repository

Running functional tests
------------------------

To run functional tests::

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
