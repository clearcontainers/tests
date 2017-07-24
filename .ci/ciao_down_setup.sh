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

# This setup will be used to run the CI tests under ciao-down
# under SemaphoreCI. This will avoid issues with the old packages
# that comes in the SempahoreCI environment (Ubuntu 14.04). 

set -e

cidir=$(dirname "$(readlink -f "$0")")

if [ -z $CI ] || [ -z "$LOCALCI_REPO_SLUG" ] || [ -z "$LOCALCI" ]; then
	echo "	If you are running locally, please set environment variables
	CI=true
	LOCALCI=true
	LOCALCI_REPO_SLUG with the value of the repo you want to test.
	For example:
	export LOCALCI_REPO_SLUG=clearcontainers/tests
	If you want to test an specific PR, please also add env variable:
	LOCALCI_PR_NUMBER, for example:
	export LOCALCI_PR_NUMBER=100" && exit 1
fi

ciao_repo="github.com/01org/ciao"

# This function will clone the repo inside the VM and
# get the current PR that will be tested.
function install_repo_inside_vm(){
	export $(cat "${HOME}/ci_environment")
	repo_slug="$LOCALCI_REPO_SLUG"
	pr_number="$LOCALCI_PR_NUMBER"
	if [ -n "$SEMAPHORE" ]; then
		repo_slug="$SEMAPHORE_REPO_SLUG"
		pr_number="$PULL_REQUEST_NUMBER"
	fi
	go get -d "github.com/${repo_slug}" || true
	if [ -n "$pr_number" ]; then
		pushd "${GOPATH}/src/github.com/${repo_slug}"
		git fetch origin "refs/pull/${pr_number}/head:pull_${pr_number}"
		git checkout "pull_${pr_number}"
	fi
}

# Get ciao-down repository
go get -u -t -d -v "${ciao_repo}/..." || true
pushd "${GOPATH}/src/${ciao_repo}"
go install -v ./...
popd
export PATH=$GOPATH/bin:$PATH

# Provide access to /dev/kvm to the curent user to launch VMs using ciao-down
sudo chmod a+rw /dev/kvm

# Execute ciao-down
vm_cpus=2
vm_mem=2
ciao-down create -debug -cpus "$vm_cpus" -mem "$vm_mem" "file://${cidir}/data/cc3-ubuntu-xenial.yaml"

# Get LocalCI or SemaphoreCI Env variables that may be useful inside the ciao-down VM
echo "Get Semaphore Env Variables"
ci_environment_file="$HOME/ci_environment"
env | egrep "PULL_REQ|SLUG|SEMAPHORE|BRANCH|CI" > "$ci_environment_file" || true

# Get information to connect via SSH
ssh_options="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o IdentitiesOnly=yes"
ssh_key="$HOME/.ciao-down/id_rsa"

vm_info_file="$HOME/vm_info"
myssh=$(ciao-down status | grep ssh |  cut -d : -f 2)
vm_ip=$(echo "$myssh" | cut -d " " -f 11)
echo "vm_ip=$vm_ip" > "$vm_info_file"
vm_port=$(echo "$myssh" | cut -d " " -f 13)
echo "vm_port=$vm_port" >> "$vm_info_file"

echo "Add CI Environment Variables to nested VM"
scp -r -q $ssh_options -i "$ssh_key" -P "$vm_port" "$ci_environment_file" "$USER@$vm_ip:"
ssh $ssh_options -i "$ssh_key" "$USER@$vm_ip" -p "$vm_port" "sudo bash -c \"cat $ci_environment_file >> /etc/environment\""

echo "Install repo inside nested VM"
ssh $ssh_options -i "$ssh_key" "$USER@$vm_ip" -p "$vm_port" "$(typeset -f); install_repo_inside_vm"

echo "Install dependencies inside the VM"
ssh $ssh_options -i "$ssh_key" "$USER@$vm_ip" -p "$vm_port" "${cidir}/ciao_down_setup_env_ubuntu.sh"
ssh $ssh_options -i "$ssh_key" "$USER@$vm_ip" -p "$vm_port" "${cidir}/ciao_down_setup_cc3.sh"
