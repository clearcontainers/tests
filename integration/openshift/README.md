# OpenShift\* integration with Clear Containers

This section contains scripts to setup an OpenShift enviornment on top
of Clear Containers. Currently, these scripts only work for **Fedora**.

Execute the steps below on a clean environment.

Setup the environment:

```
$ ./setup.sh
```

Initialize the master server and the node server:

```
$ ./init.sh
```

Run a basic verification test to check the environment was built correctly
(recommended). To run the test you need the `bats` framework.

```
$ bats hello_world.bats
```
