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
declare     BUILD_TARGET_SOURCE_DIRECTORY="${BUILD_SOURCE_DIRECTORY}/support"

declare -a  FSBUNDLE_KEXT_TASKS=()
declare     FSBUNDLE_TARGET_DIRECTORY_DEBUG=""


function fsbundle_build
{
    function fsbundle_build_getopt_handler
    {
        case "${1}" in
            --kext)
                FSBUNDLE_KEXT_TASKS+=("${2}")
                return 2
                ;;
        esac
    }

    build_target_getopt -p build -s "kext:" -h fsbundle_build_getopt_handler -- "${@}"
    unset fsbundle_build_getopt_handler

    if [[ `array_size FSBUNDLE_KEXT_TASKS` -eq 0 ]]
    then
        FSBUNDLE_KEXT_TASKS+=("${BUILD_TARGET_OPTION_SDK}")
    fi
    common_log_variable FSBUNDLE_KEXT_TASKS

    common_log "Clean target"
    build_target_invoke "${BUILD_TARGET_NAME}" clean
    common_die_on_error "Failed to clean target"

    common_log "Build target for macOS ${BUILD_TARGET_OPTION_DEPLOYMENT_TARGET}"

    local debug_directory="${BUILD_TARGET_BUILD_DIRECTORY}/Debug"

    # Build file system bundle

    build_target_xcodebuild -project osxfusefs.xcodeproj -target osxfuse.fs \
                            clean build
    common_die_on_error "Failed to build target"

    local fsbundle_path=""
    fsbundle_path="`osxfuse_find "${BUILD_TARGET_BUILD_DIRECTORY}"/*.fs`"
    common_die_on_error "Failed to locate file system bundle"

    # Build kernel extensions

    local kext_build_directory="`build_target_get_build_directory kext`"
    local fsbundle_kext_directory="${fsbundle_path}/Contents/Extensions"

    for task in "${FSBUNDLE_KEXT_TASKS[@]}"
    do
        if [[ "${task}" =~ "->" ]]
        then
            # Link kernel extension

            local link_source="${task#*->}"
            local link_target="${task%->*}"

            /bin/ln -s "${link_source}" "${fsbundle_kext_directory}/${link_target}"
            common_die_on_error "Failed to create link ${link_target} to ${link_source}"

        else
            # Build kernel extension

            local macos_version="${task}"

            build_target_invoke kext build -s "${macos_version}" \
                                           "${BUILD_TARGET_OPTION_BUILD_SETTINGS[@]/#/-b}" \
                                           "${BUILD_TARGET_OPTION_MACROS[@]/#/-m}" \
                                           "--code-sign-identity=${BUILD_TARGET_OPTION_CODE_SIGN_IDENTITY}" \
                                           "--product-sign-identity=${BUILD_TARGET_OPTION_PRODUCT_SIGN_IDENTITY}"
            common_die_on_error "Failed to build macOS ${macos_version} kernel extension"

            local kext_directory="${fsbundle_kext_directory}/${macos_version}"
            local kext_debug_directory="${debug_directory}/kext-${macos_version}"

            /bin/mkdir -p "${kext_directory}" 1>&3 2>&4
            common_die_on_error "Failed to create macOS ${macos_version} kernel extension target directory"

            /bin/mkdir -p "${kext_debug_directory}" 1>&3 2>&4
            common_die_on_error "Failed to create macOS ${macos_version} debug kernel extension target directory"

            build_target_invoke kext install --debug="${kext_debug_directory}" -- "${kext_directory}"
            common_die_on_error "Failed to install macOS ${macos_version} kernel extension"
        fi
    done

    # Sign file system bundle

    build_target_codesign "${fsbundle_path}"
    common_die_on_error "Failed to sign file system bundle"
}

function fsbundle_install
{
    function fsbundle_install_getopt_handler
    {
        case "${1}" in
            --debug)
                FSBUNDLE_TARGET_DIRECTORY_DEBUG="${2}"
                return 2
                ;;
        esac
    }

    local -a arguments=()
    build_target_getopt -p install -s "debug:" -h fsbundle_install_getopt_handler -o arguments -- "${@}"


    local target_directory="${arguments[0]}"
    if [[ ! -d "${target_directory}" ]]
    then
        common_die "Target directory '${target_directory}' does not exist"
    fi

    common_log "Install target"

    local fsbundle_source_path=""
    fsbundle_source_path="`osxfuse_find "${BUILD_TARGET_BUILD_DIRECTORY}"/*.fs`"
    common_die_on_error "Failed to locate file system bundle"

    build_target_install "${fsbundle_source_path}" "${target_directory}"
    common_die_on_error "Failed to install target"

    if [[ -n "${BUILD_TARGET_OPTION_DEBUG_DIRECTORY}" ]]
    then
        build_target_install "${BUILD_TARGET_BUILD_DIRECTORY}/Debug/" "${BUILD_TARGET_OPTION_DEBUG_DIRECTORY}"
        common_die_on_error "Failed to Install debug files"
    fi
}
