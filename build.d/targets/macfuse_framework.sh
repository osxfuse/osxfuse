#!/usr/bin/env bash

# Copyright (c) 2011-2014 Benjamin Fleischer
# All rights reserved.
#
# Redistribution  and  use  in  source  and  binary  forms,  with   or   without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above  copyright  notice,
#    this list of conditions and the following disclaimer in  the  documentation
#    and/or other materials provided with the distribution.
# 3. Neither the name of osxfuse nor the names of its contributors may  be  used
#    to endorse or promote products derived from this software without  specific
#    prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND  CONTRIBUTORS  "AS  IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING,  BUT  NOT  LIMITED  TO,  THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS  FOR  A  PARTICULAR  PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE  COPYRIGHT  OWNER  OR  CONTRIBUTORS  BE
# LIABLE  FOR  ANY  DIRECT,  INDIRECT,  INCIDENTAL,   SPECIAL,   EXEMPLARY,   OR
# CONSEQUENTIAL  DAMAGES  (INCLUDING,  BUT  NOT  LIMITED  TO,   PROCUREMENT   OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF  USE,  DATA,  OR  PROFITS;  OR  BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND  ON  ANY  THEORY  OF  LIABILITY,  WHETHER  IN
# CONTRACT, STRICT  LIABILITY,  OR  TORT  (INCLUDING  NEGLIGENCE  OR  OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN  IF  ADVISED  OF  THE
# POSSIBILITY OF SUCH DAMAGE.


function macfuse_framework_build
{
    function macfuse_framework_build_getopt_handler
    {
        case "${1}" in
            --library-prefix)
                MACFUSE_FRAMEWORK_LIBRARY_PREFIX="${2}"
                return 2
                ;;
        esac
    }

    bt_target_getopt -p build -s "library-prefix:" -h macfuse_framework_build_getopt_handler -- "${@}"
    unset macfuse_framework_build_getopt_handler

    bt_log_variable MACFUSE_FRAMEWORK_LIBRARY_PREFIX

    bt_log "Clean target"
    bt_target_invoke "${BT_TARGET_NAME}" clean
    bt_exit_on_error "Failed to clean target"

    bt_log "Build target for OS X ${BT_TARGET_OPTION_DEPLOYMENT_TARGET}"

    bt_target_xcodebuild -project MacFUSE.xcodeproj -target MacFUSE \
            MACFUSE_LIBRARY_PREFIX="${MACFUSE_FRAMEWORK_LIBRARY_PREFIX}" \
            clean build
    bt_exit_on_error "Failed to build target"
}

function macfuse_framework_install
{
    local -a arguments=()
    bt_target_getopt -p install -o arguments -- "${@}"

    local target_directory="${arguments[0]}"
    if [[ ! -d "${target_directory}" ]]
    then
        bt_error "Target directory '${target_directory}' does not exist"
    fi

    bt_log "Install target"

    local framework_source_path=""
    framework_source_path="`osxfuse_find "${BT_TARGET_BUILD_DIRECTORY}"/*.framework`"
    bt_exit_on_error "Failed to locate framework"

    bt_target_install "${framework_source_path}" "${target_directory}"
    bt_exit_on_error "Failed to install target"

    if [[ -n "${BT_TARGET_OPTION_DEBUG_DIRECTORY}" ]]
    then
        local framework_dsym_source_path=""
        framework_dsym_source_path="`osxfuse_find "${BT_TARGET_BUILD_DIRECTORY}"/*.framework.dSYM`"
        bt_exit_on_error "Failed to locate framework debug information"

        bt_target_install "${framework_dsym_source_path}" "${BT_TARGET_OPTION_DEBUG_DIRECTORY}"
        bt_exit_on_error "Failed to Install debug files"
    fi
}


# Defaults

declare -ra BT_TARGET_ACTIONS=("build" "clean" "install")
declare     BT_TARGET_SOURCE_DIRECTORY="${BT_SOURCE_DIRECTORY}/macfuse_framework"

declare MACFUSE_FRAMEWORK_LIBRARY_PREFIX="/usr/local"
