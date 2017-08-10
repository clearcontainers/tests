#!/bin/bash

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

#---------------------------------------------------------------------
# Description: This script is the *ONLY* place where "qemu*" build options
# should be defined.
#
# Note to maintainers:
#
# XXX: Every option group *MUST* be documented explaining why it has
# been specified.
#---------------------------------------------------------------------

script_name=${0##*/}

# Display message to stderr and exit indicating script failed.
die()
{
    local msg="$*"
    echo >&2 "$script_name: ERROR: $msg"
    exit 1
}

# Display usage to stdout.
usage()
{
cat <<EOT
Overview:

    Display configure options required to build the specified
    hypervisor.

Usage:

    $script_name [options] <hypervisor-name>

Options:

    -m : Display options one per line (includes continuation characters).

Example:

    $ $script_name qemu-lite

EOT
}

# Display an array to stdout.
#
# If 2 arguments are specified, split array across multiple lines,
# one per element with a backslash at the end of all lines except
# the last.
#
# Arguments:
#
# $1: *Name* of array variable (no leading '$'!!)
# $2: any value (optional)
show_array()
{
    local -n _array="$1"

    local show_multi_line=no

    [ -n "$2" ] && show_multi_line=yes

    if [ "$show_multi_line" = no ]; then
        echo "${_array[@]}"
        return
    fi

    local -i size="${#_array[*]}"
    local -i i=1
    local suffix
    local elem

    for elem in "${_array[@]}"
    do
        if [ $i -eq $size ]
        then
            suffix=""
        else
            suffix=" \\"
        fi

        printf '%s%s\n' "$elem" "$suffix"
        i+=1
    done
}

# Entry point
main()
{
    typeset -a qemu_options
    multi_line=no

    while getopts "hm" opt
    do
        case "$opt" in
            h)
                usage
                exit 0
                ;;

            m)
                multi_line="yes"
                ;;
        esac
    done

    shift $[$OPTIND-1]

    [ -z "$1" ] && die "need hypervisor name"
    hypervisor="$1"

    #---------------------------------------------------------------------
    # Disabled options

    # bluetooth support not required
    qemu_options+=(--disable-bluez)

    # braille support not required
    qemu_options+=(--disable-brlapi)

    # Don't build documentation
    qemu_options+=(--disable-docs)

    # Disable GUI (graphics)
    qemu_options+=(--disable-curses)
    qemu_options+=(--disable-gtk)
    qemu_options+=(--disable-opengl)
    qemu_options+=(--disable-sdl)
    qemu_options+=(--disable-spice)
    qemu_options+=(--disable-vte)

    # Disable graphical network access
    qemu_options+=(--disable-vnc)
    qemu_options+=(--disable-vnc-jpeg)
    qemu_options+=(--disable-vnc-png)
    qemu_options+=(--disable-vnc-sasl)

    # Disable unused filesystem support
    qemu_options+=(--disable-fdt)
    qemu_options+=(--disable-glusterfs)
    qemu_options+=(--disable-libiscsi)
    qemu_options+=(--disable-libnfs)
    qemu_options+=(--disable-libssh2)
    qemu_options+=(--disable-rbd)

    # Disable unused compression support
    qemu_options+=(--disable-bzip2)
    qemu_options+=(--disable-lzo)
    qemu_options+=(--disable-snappy)

    # SECURITY: Disable unused security options
    qemu_options+=(--disable-seccomp)
    qemu_options+=(--disable-tpm)

    # Disable userspace network access ("-net user")
    qemu_options+=(--disable-slirp)

    # Disable USB
    qemu_options+=(--disable-libusb)
    qemu_options+=(--disable-usb-redir)

    # SECURITY: Don't build a static binary (lowers security)
    qemu_options+=(--disable-static)

    # Not required as "-uuid ..." is always passed to the qemu binary
    qemu_options+=(--disable-uuid)

    # Disable debug
    qemu_options+=(--disable-debug-tcg)
    qemu_options+=(--disable-qom-cast-debug)
    qemu_options+=(--disable-tcg-interpreter)
    qemu_options+=(--disable-tcmalloc)

    # SECURITY: Disallow network downloads
    qemu_options+=(--disable-curl)

    # Disable Remote Direct Memory Access (Live Migration)
    # https://wiki.qemu.org/index.php/Features/RDMALiveMigration
    qemu_options+=(--disable-rdma)

    # Don't build the qemu-io, qemu-nbd and qemu-image tools
    qemu_options+=(--disable-tools)

    # Disable XEN driver
    qemu_options+=(--disable-xen)

    # FIXME: why is this disabled?
    # (for reference, it's explicitly enabled in Ubuntu 17.10 and
    # implicitly enabled in Fedora 27).
    qemu_options+=(--disable-linux-aio)

    # In "passthrough" security mode
    # (-fsdev "...,security_model=passthrough,..."), qemu uses a helper
    # application called virtfs-proxy-helper(1) to make certain 9p
    # operations safer. We don't need that, so disable it (and it's
    # dependencies).
    qemu_options+=(--disable-virtfs)
    qemu_options+=(--disable-attr)
    qemu_options+=(--disable-cap-ng)

    #---------------------------------------------------------------------
    # Enabled options

    # Enable kernel Virtual Machine support.
    # This is the default, but be explicit to avoid any future surprises
    qemu_options+=(--enable-kvm)

    # Required for fast network access
    qemu_options+=(--enable-vhost-net)

    # Always strip binaries
    qemu_options+=(--enable-strip)

    #---------------------------------------------------------------------
    # Other options

    # 64-bit only
    qemu_options+=(--target-list=x86_64-softmmu)

    _qemu_cflags=""

    # compile with high level of optimisation
    _qemu_cflags+=" -O3"

    # Improve code quality by assuming identical semantics for interposed
    # synmbols.
    _qemu_cflags+=" -fno-semantic-interposition"

    # Performance optimisation
    _qemu_cflags+=" -falign-functions=32"

    # SECURITY: make the compiler check for common security issues
    # (such as argument and buffer overflows checks).
    _qemu_cflags+=" -D_FORTIFY_SOURCE=2"

    # SECURITY: Create binary as a Position Independant Executable,
    # and take advantage of ASLR, making ROP attacks much harder to perform.
    # (https://wiki.debian.org/Hardening)
    _qemu_cflags+=" -fPIE"

    # Set compile options
    qemu_options+=("--extra-cflags=\"${_qemu_cflags}\"")

    unset _qemu_cflags

    _qemu_ldflags=""

    # SECURITY: Link binary as a Position Independant Executable,
    # and take advantage of ASLR, making ROP attacks much harder to perform.
    # (https://wiki.debian.org/Hardening)
    _qemu_ldflags+=" -pie"

    # SECURITY: Disallow executing code on the stack.
    _qemu_ldflags+=" -z noexecstack"

    # SECURITY: Make the linker set some program sections to read-only
    # before the program is run to stop certain attacks.
    _qemu_ldflags+=" -z relro"

    # SECURITY: Make the linker resolve all symbols immediately on program
    # load.
    _qemu_ldflags+=" -z now"

    qemu_options+=("--extra-ldflags=\"${_qemu_ldflags}\"")

    unset _qemu_ldflags

    # Where to install qemu libraries
    qemu_options+=(--libdir=/usr/lib64/${hypervisor})

    # Where to install qemu helper binaries
    qemu_options+=(--libexecdir=/usr/libexec/${hypervisor})

    # Where to install data files
    qemu_options+=(--datadir=/usr/share/${hypervisor})

    if [ "$multi_line" = yes ]
    then
        show_array qemu_options true
    else
        show_array qemu_options
    fi
}

main $@
