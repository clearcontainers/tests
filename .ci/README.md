# Continuous Integration scripts #

This directory contains a set of files to run the Clear Containers CI
test.

The main files used by the CI are : 

- `setup.sh`: Sets the needed environment to run Clear Containers tests

- `run.sh`: Runs Clear Containers tests in this repository

The Clear Containers CI uses the latest components from the Clear
Containers project: runtime, proxy, and shim are built and installed from
source. But the kernel, hypervisor, and Clear Containers image are
pre-built and downloaded as binaries to reduce CI execution time.

## Clear Containers Kernel for CI ##

Each time the CI environment is configured, the kernel is downloaded from
the [Clear Containers Linux fork release
page](https://github.com/clearcontainers/linux/releases). 

The Clear Containers Linux fork provides the kernel configuration and
required patches for Clear Containers. The patches and configuration are
tracked in the [Clear Containers packaging
repository](https://github.com/clearcontainers/packaging/tree/master/kernel).
When a new change is done in the packaging repository, the fork is updated
and binaries are updated in a GitHub release. For more details about the
update sequence, see [Kernel Update
Sequence](https://github.com/clearcontainers/packaging/tree/master/kernel#update-sequence).

The script `./install_asset.sh kernel latest` is used to install the
latest kernel binaries.


## Clear Containers Image for CI ##

The CI environment is configured to download the guest OS image from the
[osbuilder image
releases](https://github.com/clearcontainers/osbuilder/releases). 

The script `./install_asset.sh image latest` is used to install the latest
guest image.

** Note: The script downloads the latest kernel each time the CI is
configured, for Clear Containers users it is highly recommended to install
the kernel from the Clear Containers packages (see [installation
guide](https://github.com/clearcontainers/runtime/wiki/Installation)).

Each time a new Clear Containers release is done, the 
`clear_container_kernel` variable in the file
[versions.txt](https://github.com/clearcontainers/runtime/blob/master/versions.txt)
is updated to define the recommended kernel version to use for the Clear
Containers release. For more details about the Clear Containers kernel
update, see [assets
update](https://github.com/clearcontainers/runtime/blob/master/docs/assets-update.md#clear-containers-kernel-update).**
