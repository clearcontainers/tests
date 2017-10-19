#!/bin/bash
#
# Copyright (c) 2017 Intel Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Description: This script will make the next flow
#
# 1) Create a group in azure
# 2) Create a VM
# 3) Create a disk
# 4) Attach previous disk to VM
# 5) Set up Clear containers stuff.
#
# Requirments:
# Azure-cli V2.0 https://github.com/Azure/azure-cli
# Being logged previously (az login)

MYSELF="${0##*/}"

# Azure/VM configuration
RESOURCE_GROUP="cc-metrics"
VM_NAME="vm-metrics"
OS_SYSTEM="UbuntuLTS"
VM_SIZE="Standard_D2s_v3"
CLOUD_INIT_FILE="cloud-init.txt"
VM_ADMIN_USER="adminazure"

# Disk configuration
DISK_NAME="devicemapper"
DISK_CACHING="ReadWrite"
DISK_SIZE=1025

# Help menu
function help()
{
	echo "$(cat << EOF
Usage: $MYSELF [-h] [--help] [-v] [--version]
   Description:
	 This script will launch a VM using Azure
         API, and install all stuff needed for
         Clear Containers.
         NOTE: it is necessary to be logged (az login)
         before to run this script.
   Options:
         -c   Cloud init file
         -d   Devicemapper disk size
         -g   Resource group
         -h   Help page
         -n   VM name
         -o   OS system
         -s   VM size (e.g. Standard_D2s_v3)
         -v   Show version
EOF
)"
}

function create_group() {
	# Create Resource group
	az group create \
		--name "$RESOURCE_GROUP" \
		--location eastus
}

function create_vm() {
	# Create Virtual Machine
	az vm create \
		--resource-group "$RESOURCE_GROUP" \
		--name "$VM_NAME" \
		--image "$OS_SYSTEM" \
		--admin-username "$VM_ADMIN_USER" \
		--size "$VM_SIZE" \
		--generate-ssh-keys \
		--custom-data cloud-init.txt
}

function delete_group() {
	# Delete a group includes the Virtual Machine and all stuff
	# related to that such as: network, storage etc.
	az group delete --name "$RESOURCE_GROUP"
}

# This disk is created in order to be attached to an Azure VM
# and configure devicemapper storage driver support
function create_dvm_disk() {
	az disk create \
		--resource-group "$RESOURCE_GROUP" \
		--name "$DISK_NAME" \
		--size-gb "$DISK_SIZE"
}

function attach_dvm_disk() {
	az vm disk attach \
		--resource-group "$RESOURCE_GROUP" \
		--vm-name "$VM_NAME" \
		--disk "$DISK_NAME" \
		--caching "$DISK_CACHING"
}

function main() {
	local OPTIND
	while getopts ":c:d:g:hn:o:s:v " opt; do
		case ${opt} in
		c) CLOUD_INIT_FILE="${OPTARG}"
		   ;;
		d) DISK_SIZE="${OPTARG}"
		   ;;
		g) RESOURCE_GROUP="${OPTARG}"
		   ;;
		h)
		   help
		   exit 0;
		   ;;
		n) VM_NAME="${OPTARG}"
		   ;;
		o) OS_SYSTEM="${OPTARG}"
		   ;;
		s) VM_SIZE="${OPTARG}"
		   ;;
		v)
		   echo "$MYSELF version 0.1"
		   exit 0;
		   ;;
		esac
	done
	shift $((OPTIND-1))

	# Execute azure/VM creation flow
	create_group
	create_dvm_disk
	create_vm
	attach_dvm_disk
}

main "$@"
