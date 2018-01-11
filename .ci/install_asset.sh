#!/bin/bash
#
# Copyright (c) 2018 Intel Corporation
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

set -e

repo_owner="clearcontainers"
latest=false
readonly runtime_versions_url="https://raw.githubusercontent.com/${repo_owner}/runtime/master/versions.txt"
readonly versions_txt="$GOPATH/src/github.com/${repo_owner}/runtime/versions.txt"
#fake repository dir to query kernel and image  version from remote
fake_repo_dir=$(mktemp -t -d assets.XXXX)

function usage() {
	cat << EOT
Usage: $0 <kernel|image> <version>
Install clear containers asset (kernel or image) <version>.


image:   When 'latest' version is used, if image is does not exist on github, it will build it
         using version.txt file from ${repo_owner}/runtime.

         It will check for versions file in the next order:
	       - ${versions_txt}
	       - ${runtime_versions_url}

kernel:  If 'latest' version is used, this script will download the latest kernel published in
	${https://github.com/${repo_owner}/linux/releases}

version: Use 'latest' to pull latest asset version

EOT

	exit 1
}

asset="$1"
version="$2"
[ -z "${asset}" ] && usage
[ -z "${version}" ] && usage

function cleanup {
	rm  -rf "${fake_repo_dir}"
}

trap cleanup EXIT



die(){
	msg="$*"
	echo "ERROR: ${msg}" >&2
	exit 1
}


resolve_version() {
	local repo="$1"
	local version="$2"

	[ -n "${version}" ] || die "version not provided"
	[ -n "${repo}" ] || die "repo not provided"

	[ "${version}" == "latest" ] && version=$(get_latest_version "${repo}")
	echo "$version"
}
#Get latest version by checking remote tags
#We dont ask to github api directly because force a user to provide a GITHUB token
function get_latest_version {
	repo="${1}"
	[ -n "${repo}" ] || die "repo not provided"

	pushd ${fake_repo_dir} >> /dev/null
	git init -q
	git remote add origin  "https://github.com/${repo_owner}/${repo}.git"

	case "$asset" in
		kernel)
			cc_release=$(git ls-remote --tags 2>/dev/null \
				| grep -oP '\-\d+\.container'  \
				| grep -oP '\d+' \
				| sort -n | \
				tail -1 )

			# Kernel version is incremental we take the latest revision.
			tag=$(git ls-remote --tags 2>/dev/null \
				| grep -oP "v\d+\.\d+\.\d+\-${cc_release}.container" \
				| tail -1)
			;;
		image)
			    # Image version is formed bt agent version and clear linux version.
			    # This variables are taked from versions.txt file
				tag="cc-${clear_vm_image_version}-agent-${cc_agent_version:0:6}"
			;;
		*)
			die "unknown asset $asset"
			;;
	esac

	popd >> /dev/null
	echo "${tag}"
}

function build_asset {
	local asset="$1"
	case "$asset" in
		image)
			packaging="github.com/${repo_owner}/packaging"
			go get -d -u  ${packaging} || true
			"$GOPATH/src/${packaging}/release-tools/release_image_github.sh" -o "${PWD}" -a ${cc_agent_version} -c ${clear_vm_image_version} release
			;;
		*)
			die "Dont know how to build $asset"
			;;
	esac
}


function download_asset {
	local asset="$1"
	local version="$2"

	[ -n "${asset}" ] || die "asset is needed"
	[ -n "${version}" ] || die "version is needed"

	[ "${version}" == "latest" ] && latest="true"

	if [ -f "${versions_txt}" ];then
		echo "Using ${versions_txt}"
		source ${versions_txt}
	else
		echo "Using ${runtime_versions_url}"
		source <(curl -sL "${runtime_versions_url}")
	fi

	case "$asset" in
		kernel)
			repo_name=linux
			#tarball version-binaries
			binaries_dir_fmt='%s-binaries'
			;;
		image)
			repo_name=osbuilder
			#tarball name is image-version-binaries
			binaries_dir_fmt='image-%s-binaries'
			;;
		*)
			echo "unknown asset $asset"
			usage
			;;
	esac

	version=$(resolve_version "$repo_name" "$version")
	echo "version to install ${version}"

	printf -v binaries_dir "${binaries_dir_fmt}" "${version}"
	local binaries_tarball="${binaries_dir}.tar.gz"
	local shasum_file="SHA512SUMS"
	local releases_url="https://github.com/${repo_owner}/${repo_name}/releases"
	tar_url="${releases_url}/download/${version}/${binaries_tarball}"
	sha_url="${releases_url}/download/${version}/${shasum_file}"
	
	echo "download $tar_url"
	STATUSCODE=$(curl -OL  --write-out "%{http_code}" "${tar_url}")

	if [ "$STATUSCODE" == "200" ]; then
		echo "download $sha_url"
		curl -OL "${sha_url}"
		sha512sum -c ${shasum_file}
	elif [ ${latest} == "true" ]; then
		# Latest is release is not created yet, build it
		build_asset "${asset}"
	else
		die "Failed to find asset version ${version}"
	fi
	tar xf "${binaries_tarball}"
	pushd "${binaries_dir}"
	sudo make install
	popd
}


download_asset "$asset" "${version}"
