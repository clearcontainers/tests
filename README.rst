Tests
=====

Clear Containers Tests Repository

Functional tests
----------------
To run all functional tests, run::

  $ make functional


By default, the functional tests use the version of ``cc-runtime`` set in the environment variable ``RUNTIME``
but you can easily change it using `Environment variables`_.
For example::

  $ RUNTIME="/usr/local/bin/cc-runtime" make functional

In the above example the version installed in ``/usr/local/bin`` of the Runtime is used.

Environment variables
---------------------

- `RUNTIME` - Path of Clear Containers Runtime, the default path is ``cc-runtime``
- `TIMEOUT` - Time limit in seconds for each test, the default timeout is ``5``
