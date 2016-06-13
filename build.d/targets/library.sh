#!/bin/bash

# Copyright (c) 2011-2015 Benjamin Fleischer
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
# 3. Neither the name of osxfuse nor the names of its contributors may be used
#    to endorse or promote products derived from this software without specific
#    prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.


declare -ra BUILD_TARGET_ACTIONS=("build" "clean" "install")
declare     BUILD_TARGET_SOURCE_DIRECTORY="${BUILD_SOURCE_DIRECTORY}/fuse"

declare     BUILD_TARGET_OPTION_PREFIX="/usr/local"

function library_build
{
    build_target_getopt -p make-build -- "${@}"

    common_log "Clean target"
    build_target_invoke "${BUILD_TARGET_NAME}" clean
    common_die_on_error "Failed to clean target"

    common_log "Build target for OS X ${BUILD_TARGET_OPTION_DEPLOYMENT_TARGET}"

    local source_directory="${BUILD_TARGET_BUILD_DIRECTORY}/Source"
    local debug_directory="${BUILD_TARGET_BUILD_DIRECTORY}/Debug"

    /bin/mkdir -p "${BUILD_TARGET_BUILD_DIRECTORY}" 1>&3 2>&4
    common_die_on_error "Failed to create build directory"

    /bin/mkdir -p "${source_directory}" 1>&3 2>&4
    common_die_on_error "Failed to create source code directory"

    /bin/mkdir -p "${debug_directory}" 1>&3 2>&4
    common_die_on_error "Failed to create debug directory"

    # Copy source code to build directory

    /usr/bin/rsync -a --exclude=".git*" "${BUILD_TARGET_SOURCE_DIRECTORY}/" "${source_directory}" 1>&3 2>&4
    common_die_on_error "Failed to copy source code to build directory"

    # Build library

    pushd "${source_directory}" > /dev/null 2>&1
    common_die_on_error "Source directory '${source_directory}' does not exist"

    ./makeconf.sh 1>&3 2>&4
    common_die_on_error "Failed to make configuration"

    CFLAGS="-D_DARWIN_USE_64_BIT_INODE ${BUILD_TARGET_OPTION_BUILD_SETTINGS[@]/#/-D} -I${BUILD_SOURCE_DIRECTORY}/common" \
    LDFLAGS="-Wl,-framework,CoreFoundation" \
    build_target_configure --disable-dependency-tracking --disable-static --disable-example
    common_die_on_error "Failed to configure target"

    build_target_make -- -j 4
    common_die_on_error "Failed to build target"

    local executable_path=""
    while IFS=$'\0' read -r -d $'\0' executable_path
    do
        local executable_name="`basename "${executable_path}"`"

        # Link library debug information

        /usr/bin/xcrun dsymutil -o "${debug_directory}/${executable_name}.dSYM" "${executable_path}" 1>&3 2>&4
        common_die_on_error "Failed to link debug information: '${executable_path}'"

        # Strip library

        /usr/bin/xcrun strip -S -x "${executable_path}" 1>&3 2>&4
        common_die_on_error "Failed to strip executable: '${executable_path}'"

        # Sign library

        build_target_codesign "${executable_path}"
        common_die_on_error "Failed to sign executable: '${executable_path}'"
    done < <(/usr/bin/find lib -name lib*.dylib -type f -print0)

    popd > /dev/null 2>&1
}

function library_install
{
    local -a arguments=()
    build_target_getopt -p make-install -o arguments -- "${@}"

    local target_directory="${arguments[0]}"
    if [[ ! -d "${target_directory}" ]]
    then
        common_die "Target directory '${target_directory}' does not exist"
    fi

    common_log "Install target"

    local source_directory="${BUILD_TARGET_BUILD_DIRECTORY}/Source"
    local debug_directory="${BUILD_TARGET_BUILD_DIRECTORY}/Debug"

    pushd "${source_directory}" > /dev/null 2>&1
    common_die_on_error "Source directory '${source_directory}' does not exist"

    build_target_make -- install prefix="${BUILD_TARGET_OPTION_PREFIX}" DESTDIR="${target_directory}"
    common_die_on_error "Failed to install target"

    popd > /dev/null 2>&1

    if [[ -n "${BUILD_TARGET_OPTION_DEBUG_DIRECTORY}" ]]
    then
        build_target_install "${debug_directory}/" "${BUILD_TARGET_OPTION_DEBUG_DIRECTORY}"
        common_die_on_error "Failed to Install debug files"
    fi
}
