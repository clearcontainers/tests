# Clear Containers on a Microsoft* Azure* virtual machine

This project allows you to launch an Azure virtual machine (VM) and install all Clear
Container components and dependencies in order to run Clear Containers.

## Prerequisites

* Install [Azure CLI 2.0](https://github.com/Azure/azure-cli)
* Log in to Azure

  ```bash
  $ az login
  ```

## Usage

```bash
$ bash cc-setup-azure.sh
```

## Options

To see available options, run:

```
$ bash cc-setup-azure.sh -h
```

## Example

```bash
$ bash cc-setup-azure.sh -n MyTestVM -g MyTestGroup
```

## Login VM

This script uses a default username that can be overwritten.
You can log in to the VM by using the SSH command and providing
the username and the assigned IP address.
