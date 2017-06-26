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

#
# This script will store the results into csv files in the
# metrics 'results' directory.
# The csv file names are derived from the reported 'test name', and all
# results for a single 'test name' are collated (appended) into a single csv.

# General env
MYSELF="${0##*/}"
SCRIPT_PATH=$(dirname $(readlink -f $0))
source "${SCRIPT_PATH}/common.bash"

# Override the RESULT_DIR from the test-common.bash for the moment.
# Once all all tests are migrated to use this script, remove the
# RESULT_DIR definition from test-common.bash, as all results should
# be then stored via this script
RESULT_DIR="${SCRIPT_PATH}/../results"

GROUP="PNP"
COR_DEFAULT_PATH="/usr/bin"
COR_DEFAULT_NAME="cc-oci-runtime"
RUNC_DEFAULT_PATH="/usr/bin"
RUNC_DEFAULT_NAME="docker-runc"
CC_RUNTIME_DEFAULT_PATH="/usr/local/bin"
CC_RUNTIME_DEFAULT_NAME="cc-runtime"
CC_DEFAULT_IMG_PATH="/usr/share/clear-containers"
CONTAINERS_IMG_SYSTEM="/usr/share/clear-containers/clear-containers.img"
CONTAINERS_IMG_GUESS="${CC_DEFAULT_IMG_PATH}/clear-containers.img"
CONTAINER_KERNEL_SYSTEM="/usr/share/clear-containers/vmlinux.container"
CONTAINER_KERNEL_GUESS="${CC_DEFAULT_IMG_PATH}/vmlinux.container"
SYSTEM_CLEAR_RELEASE_FILE="/usr/lib/os-release"
SYSTEM_CENTOS_RELEASE_FILE="/etc/os-release"

declare TEST_NAME
declare RESULT
declare ARGS
declare UNITS
declare SYS_VERSION
declare SYSTEM
declare TAG
declare HW
declare SEND
declare KERNEL
declare IMG

# Parse the platform name
function get_platform_name()
{
	com="core"

	model="$(cat /proc/cpuinfo | grep "model name" | uniq | \
		awk -F ": " '{print $2}' | sed s/\(R\)//g | \
		sed s/\(TM\)//g | sed s/[[:space:]]*CPU[[:space:]]*/" "/g | \
		cut -d"@" -f1 | sed s/[[:space:]]*$//g)"

	num_cores=$(nproc)

	if (( $num_cores > 1 ));then
		com="cores"
	fi

	echo "$model ($num_cores $com)"
}


# Locate a runtime and extract its version commit info.
# Args:
#  default runtime path
#  runtime filename
function get_runtime_version()
{
	# If docker could tell us the path to the actual runtime then
	# this is where we would grab and use that info.
	RUNTIME_PATH=$1
	RUNTIME_NAME=$2

	# See if runtime is in the default place
	if [ -f "${RUNTIME_PATH}/${RUNTIME_NAME}" ];then
		runtime="${RUNTIME_PATH}/${RUNTIME_NAME}"
	else
		# And if we cannot find it at the default, can we find it
		# in the path
		runtime="$(which ${RUNTIME_NAME})"
	fi

	if [ -f "$runtime" ];then
		result="$($runtime -v | grep commit | sed s/"commit.*:"//g | awk '{print $1}')"
	else
		result="${RUNTIME_NAME}-unknown"
	fi

	echo "$result"
}

# Get commit or version info for what we believe is the runtime being used
function get_runtime_info()
{
	# If we have a RUNTIME set, then try to find and get version
	# info from that. If it is not set, make the presumption that we
	# are using the default docker runtime.
	# It will be ideal later if the higher level invokers of the
	# tests can pass in specific version info.

	if [ -z "$RUNTIME" ];then
		RUNTIME="$(docker info | grep "Default Runtime" | awk '{print $3}')"
	fi

	case "$RUNTIME" in
		cc-runtime)
			result="$(get_runtime_version ${COR_DEFAULT_PATH} ${COR_DEFAULT_NAME})"
			;;

		cor)
			result="$(get_runtime_version ${RUNC_DEFAULT_PATH} ${RUNC_DEFAULT_NAME})"
			;;

		runc)
			result="$(get_runtime_version ${CC_RUNTIME_DEFAULT_PATH} ${CC_RUNTIME_DEFAULT_NAME})"
			;;

		*)
			# Sadly not a runtime we know how to probe
			result="unknown"
			;;
	esac

	echo "$result"
}

function find_system_name()
{
	os="$(cat "$SYSTEM_RELEASE_FILE" | grep -w "ID" | cut -d "=" -f2)"

	if [ -z "$os" ];then
		os="Unknown"
	fi

	echo "$os"
}

function find_system_version()
{
	version="$(cat "$SYSTEM_RELEASE_FILE" | grep "VERSION_ID"| cut -d "=" -f2 | sed s/\"//g)"

	if [ -z "$version" ];then
		version="Unknown"
	fi

	echo "$version"
}

# Try to find the img file we are running with.
function locate_containers_img()
{
	# This is the location the build/install is configured for
	res="$CONTAINERS_IMG_SYSTEM"

	if [ ! -f "$res" ];then
		# but, sometimes we are running the tests on an already installed
		# system - try a 'backup' path
		# This is far far from perfect.
		# Ideally we'd ask the test runner or test or docker which runtime
		# and kernel and img (if appropriate for the runtime) were used
		res="$CONTAINERS_IMG_GUESS"

		if [ ! -f "$res" ];then
			res=""
		fi
	fi

	echo "$res"
}

# Try to find the VM container kernel that was used
function locate_container_kernel()
{
	# This is the location the build/install is configured for
	res="$CONTAINER_KERNEL_SYSTEM"

	if [ ! -f "$res" ];then
		# but, sometimes we are running the tests on an already installed
		# system - try a 'backup' path
		# This is far far from perfect.
		# Ideally we'd ask the test runner or test or docker which runtime
		# and kernel and img (if appropriate for the runtime) were used
		res="$CONTAINER_KERNEL_GUESS"

		if [ ! -f "$res" ];then
			res=""
		fi
	fi

	echo "$res"
}

function save_to_csv()
{

	if [ -z "$TEST_NAME" ];then
		die "test name argument not supplied"
	fi

	if [ -z "$RESULT" ];then
		die "result argument not supplied"
	fi

	if [ -z "$UNITS" ];then
		die "units argument not supplied"
	fi

	if [ -z "$HW" ];then
		platform="$(get_platform_name)"
		HW="$platform"
	fi

	if [ -z "$IMG" ];then
		CONTAINERS_IMG="$(locate_containers_img)"
		IMG="$(readlink "$CONTAINERS_IMG")"
	fi

	if [ -z "$KERNEL" ];then
		CONTAINER_KERNEL="$(locate_container_kernel)"
		KERNEL="$(readlink "$CONTAINER_KERNEL")"
	fi

	if [ -z "$TAG" ];then
		# This is somewhat imperfect. Ideally we'd have knowledge passed
		# in from the test itself about which runtime it used so we could
		# be certain to have the correct runtime and extract the correct
		# commit id
		TAG="$(get_runtime_info)"
	fi

	if [ -z "$SYSTEM" ];then
		SYSTEM="$(find_system_name)"
	fi

	if [ -z "$SYS_VERSION" ];then
		SYS_VERSION="$(find_system_version)"
	fi

	if [ -z "$ARGS" ];then
		ARGS="none"
	fi

	# Generate the file name from the test name - replace spaces and path chars
	# to hyphens
	CSV_FILE=${RESULT_DIR}/$(echo ${TEST_NAME} | sed 's/[ \/]/-/g').csv

	if [ ! -d ${RESULT_DIR} ];then
		mkdir -p ${RESULT_DIR}
	fi

	timestamp="$(date +%s)"

	# If this is the first write to the file, start with the column header
	if [ ! -f ${CSV_FILE} ];then
		s0=$(echo "Timestamp,Group,Name,Args,Result,Units,System,SystemVersion,Platform,Image,Kernel,Commit")
		if [ -z "$SEND" ];then
			echo "${s0}" > "${CSV_FILE}"
		else
			echo "Would have done: echo ${s0} > ${CSV_FILE}"
		fi
	fi

	# A bit horrid - but quote the values in the CSV just in case one has an embedded comma
	s1=$(echo "\"$timestamp\",\"$GROUP\",\"$TEST_NAME\",\"$ARGS\",\"$RESULT\",\"$UNITS\",\"$SYSTEM\",\"$SYS_VERSION\",\"$platform\",\"$IMG\",\"$KERNEL\",\"$TAG\"")

	if [ -z "$SEND" ];then
		echo "${s1}" >> "${CSV_FILE}"
	else
		echo "Would have done: echo ${s1} > ${CSV_FILE}"
	fi
}

function help()
{
	usage=$(cat << EOF
Usage: $MYSELF [-h] [--help] [-v] [--version]
   Description:
	 This tool will save results to csv files.
   Options:
	 -a   Test arguments
	 -d   Dry-run
	 -g   Group (by default PNP)
	 -h   Help page
	 -i   Clear containers image
	 -k   Clear containers kernel image
	 -n   Test name (Mandatory)
	 -o   OS version
	 -r   Test Results (Mandatory)
	 -s   Name of OS
	 -t   Git commit
	 -u   Test units, example: secs, ms, KB (Mandatory)
	 -v   Show version
	 -w   (Hardware | platform) name
EOF
)
	echo "$usage"
}

function main()
{
	local OPTIND
	while getopts ":a:dg:hi:k:n:o:r:s:t:u:vw: " opt;do
		case ${opt} in
		a)
		   ARGS="${OPTARG}"
		   ;;
		d) SEND="No"
		   ;;
		g)
		   GROUP="${OPTARG}"
		   ;;
		h)
		   help
		   exit 0;
		   ;;
		i) IMG="${OPTARG}"
		   ;;
		k) KERNEL="${OPTARG}"
		   ;;
		n)
		   TEST_NAME="${OPTARG}"
		   ;;
		o)
		   SYS_VERSION="${OPTARG}"
		   ;;
		r)
		   RESULT="${OPTARG}"
		   ;;
		s)
		   SYSTEM="${OPTARG}"
		   ;;
		t) TAG="${OPTARG}"
		   ;;
		u)
		   UNITS="${OPTARG}"
		   ;;
		v)
		   echo "$MYSELF version 0.1"
		   exit 0;
		   ;;
		w) HW="${OPTARG}"
		   ;;
		esac
	done
	shift $((OPTIND-1))

	# do some prep work to locate files
	# Try to figure out where the system release file is
	if [ -f $SYSTEM_CLEAR_RELEASE_FILE ];then
		SYSTEM_RELEASE_FILE="$SYSTEM_CLEAR_RELEASE_FILE"
	fi

	if [ -f $SYSTEM_CENTOS_RELEASE_FILE ];then
		SYSTEM_RELEASE_FILE="$SYSTEM_CENTOS_RELEASE_FILE"
	fi

	if [ -z "$SYSTEM_RELEASE_FILE" ];then
		die "Cannot locate system release file"
	fi

	save_to_csv
}

# call main
main "$@"
