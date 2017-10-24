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

# Description: This script will launch a VM using Azure API, and install
# all components needed for Clear Containers.

MYSELF="${0##*/}"

# Azure/VM configuration
RESOURCE_GROUP="cc-metrics"
VM_NAME="vm-metrics"
OS_SYSTEM="UbuntuLTS"
VM_SIZE="Standard_D2s_v3"
CLOUD_INIT_FILE="cloud-init.txt"
VM_ADMIN_USER="adminazure"
GRP_LOCATION="eastus"

# Disks configuration
DISK_CACHING="ReadWrite"

# This disk size was selected due to it gets
# a better estimation performance in:
# - IOPS limit
# - Througput limit
DISK_SIZE=1025

# Help menu
function help()
{
	echo "$(cat << EOF
Usage: $MYSELF [-h] [--help] [-v] [--version]
   Description:
   This script will make the next flow:
         1- Create a group in azure.
         2- Create a VM.
         3- Create a disk.
         4- Attach previous disk to VM.
         5- Set up Clear containers components.
         6- Install and setup Kubelet, kubeadm and CRI-O.
   Options:
         -c <file>     : Cloud init file.
         -d <size>     : Devicemapper disk size.
         -g <name>     : Resource group.
         -h            : Help page.
         -l <location> : Resource group location.
         -n <name>     : VM name.
         -o <name>     : OS system.
         -s <vm size>  : VM size (e.g. Standard_D2s_v3).
         -u <user>     : VM admin user.
         -v            : Show version.
EOF
)"
}

function create_group() {
	# Create Resource group
	az group create \
		--name "$RESOURCE_GROUP" \
		--location "$GRP_LOCATION"
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

function create_dvm_crio_disk() {
	az disk create \
		--resource-group $RESOURCE_GROUP \
		--name $DISK_NAME_CRIO \
		--size-gb $DISK_SIZE
}

function attach_dvm_crio_disk() {
	az vm disk attach \
		--resource-group $RESOURCE_GROUP \
		--vm-name $VM_NAME \
		--disk $DISK_NAME_CRIO \
		--caching $DISK_CACHING
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
		l) GRP_LOCATION="${OPTARG}"
		   ;;
		n) VM_NAME="${OPTARG}"
		   ;;
		o) OS_SYSTEM="${OPTARG}"
		   ;;
		s) VM_SIZE="${OPTARG}"
		   ;;
		u) VM_ADMIN_USER="${OPTARG}"
		   ;;
		v)
		   echo "$MYSELF version 0.1"
		   exit 0;
		   ;;
		esac
	done
	shift $((OPTIND-1))

	# Execute azure/VM creation flow
	DISK_NAME="${VM_NAME}_devmapper"
	DISK_NAME_CRIO="${VM_NAME}_devmapper_crio"
	create_group
	create_dvm_disk
	create_dvm_crio_disk
	create_vm
	attach_dvm_disk
	attach_dvm_crio_disk

}

main "$@"
