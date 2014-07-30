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


declare -ra BT_TARGET_ACTIONS=("build" "clean" "install")


function homebrew_create_stage
{
    local stage_directory="${1}"
    bt_assert "[[ -n `bt_string_escape "${stage_directory}"` ]]"

    /bin/mkdir -p "${stage_directory}" \
                  "${stage_directory}/Library/Filesystems" \
                  "${stage_directory}/Library/Frameworks" \
                  "${stage_directory}/include" \
                  "${stage_directory}/lib" \
                  "${stage_directory}/lib/pkgconfig" 1>&3 2>&4
}

function homebrew_build
{
    bt_target_getopt -p meta -s "prefix:" -- "${@}"

    bt_log "Clean target"
    bt_target_invoke "${BT_TARGET_NAME}" clean
    bt_exit_on_error "Failed to clean target"

    bt_log "Build target"

    local -a default_build_options=("-bENABLE_MACFUSE_MODE=0")

    local stage_directory="${BT_TARGET_BUILD_DIRECTORY}"
    local debug_directory="${BT_TARGET_BUILD_DIRECTORY}/Debug"

    /bin/mkdir -p "${BT_TARGET_BUILD_DIRECTORY}" 1>&3 2>&4
    bt_exit_on_error "Failed to create build directory"

    homebrew_create_stage "${stage_directory}"
    bt_exit_on_error "Failed to create stage"

    /bin/mkdir -p "${debug_directory}" 1>&3 2>&4
    bt_exit_on_error "Failed to create debug directory"

    # Build file system bundle

    bt_target_invoke fsbundle build "${default_build_options[@]}"
    bt_exit_on_error "Failed to build file system bundle"

    bt_target_invoke fsbundle install --debug="${debug_directory}" -- "${stage_directory}/Library/Filesystems"
    bt_exit_on_error "Failed to install file system bundle"

    # Build library

    bt_target_invoke library build "${default_build_options[@]}" --prefix="${BT_TARGET_OPTION_PREFIX}"
    bt_exit_on_error "Failed to build library"

    bt_target_invoke library install --debug="${debug_directory}" --prefix="" -- "${stage_directory}"
    bt_exit_on_error "Failed to install library"

    /bin/ln -s "libosxfuse.2.dylib" "${stage_directory}/lib/libosxfuse_i64.2.dylib" && \
    /bin/ln -s "libosxfuse.dylib" "${stage_directory}/lib/libosxfuse_i64.dylib" && \
    /bin/ln -s "libosxfuse.la" "${stage_directory}/lib/libosxfuse_i64.la" && \
    /bin/ln -s "osxfuse.pc" "${stage_directory}/lib/pkgconfig/fuse.pc"
    bt_exit_on_error "Failed to create legacy library links"

    # Build framework

    bt_target_invoke framework build "${default_build_options[@]}" --library-prefix="${stage_directory}"
    bt_exit_on_error "Failed to build framework"

    bt_target_invoke framework install --debug="${debug_directory}" -- "${stage_directory}/Library/Frameworks"
    bt_exit_on_error "Failed to install framework"
}

function homebrew_install
{
    local -a arguments=()
    bt_target_getopt -p install -o arguments -- "${@}"

    local target_directory="${arguments[0]}"
    if [[ ! -d "${target_directory}" ]]
    then
        bt_error "Target directory '${target_directory}' does not exist"
    fi

    bt_log "Install target"

    bt_target_install "${BT_TARGET_BUILD_DIRECTORY}/" "${target_directory}"
    bt_exit_on_error "Failed to install target"
}
