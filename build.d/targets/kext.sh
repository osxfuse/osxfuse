#!/bin/bash

# Copyright (c) 2011-2014 Benjamin Fleischer
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
declare     BUILD_TARGET_SOURCE_DIRECTORY="${BUILD_SOURCE_DIRECTORY}/kext"

declare     BUILD_TARGET_OPTION_CODE_SIGN_IDENTITY="Developer ID Application"
declare     BUILD_TARGET_OPTION_PRODUCT_SIGN_IDENTITY="Developer ID Installer"


function kext_build
{
    build_target_getopt -p build -- "${@}"

    common_log "Clean target"
    build_target_invoke "${BUILD_TARGET_NAME}" clean
    common_die_on_error "Failed to clean target"

    common_log "Build target for OS X ${BUILD_TARGET_OPTION_DEPLOYMENT_TARGET}"
    build_target_xcodebuild -project osxfuse.xcodeproj -target osxfuse clean build
    common_die_on_error "Failed to build target"
}

function kext_install
{
    local -a arguments=()
    build_target_getopt -p install -o arguments -- "${@}"

    local target_directory="${arguments[0]}"
    if [[ ! -d "${target_directory}" ]]
    then
        common_die "Target directory '${target_directory}' does not exist"
    fi

    common_log "Install target"

    local kext_source_path=""
    kext_source_path="`osxfuse_find "${BUILD_TARGET_BUILD_DIRECTORY}"/*.kext`"
    common_die_on_error "Failed to locate kernel extension"

    build_target_install "${kext_source_path}" "${target_directory}"
    common_die_on_error "Failed to install target"

    if [[ -n "${BUILD_TARGET_OPTION_DEBUG_DIRECTORY}" ]]
    then
        build_target_install "${BUILD_TARGET_BUILD_DIRECTORY}/Debug/" "${BUILD_TARGET_OPTION_DEBUG_DIRECTORY}"
        common_die_on_error "Failed to Install debug files"
    fi
}
