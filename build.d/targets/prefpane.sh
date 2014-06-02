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


function prefpane_build
{
    bt_target_getopt -p build -- "${@}"

    bt_log "Clean target"
    bt_target_invoke "${BT_TARGET_NAME}" clean
    bt_exit_on_error "Failed to clean target"

    bt_log "Build target for OS X ${BT_TARGET_OPTION_DEPLOYMENT_TARGET}"

    # Build autoinstaller

    bt_target_xcodebuild -project autoinstaller/autoinstaller.xcodeproj -target autoinstall-osxfuse-core \
                         VALID_ARCHS="ppc i386 x86_64" \
                         clean build
    bt_exit_on_error "Failed to build autoinstaller"

    # Build preference pane

    local osxfuse_version=""
    osxfuse_version="`osxfuse_get_version`"
    bt_exit_on_error "Failed to determine osxfuse version number"

    bt_target_xcodebuild -project OSXFUSEPref.xcodeproj -target OSXFUSE \
                         CODE_SIGN_IDENTITY="" \
                         OSXFUSE_VERSION="${osxfuse_version}" \
                         clean build
    bt_exit_on_error "Failed to build preference pane"

    local autoinstaller_path=""
    autoinstaller_path="`osxfuse_find "${BT_TARGET_BUILD_DIRECTORY}/autoinstall-osxfuse-core"`"
    bt_exit_on_error "Failed to locate autoinstaller"

    local prefpane_path=""
    prefpane_path="`osxfuse_find "${BT_TARGET_BUILD_DIRECTORY}"/*.prefPane`"
    bt_exit_on_error "Failed to locate preference pane"

    /bin/cp "${autoinstaller_path}" "${prefpane_path}/Contents/MacOS/autoinstall-osxfuse-core" 1>&3 2>&4
    bt_exit_on_error "Failed to copy autoinstaller in preference pane bundle"

    # Sign preference pane

    bt_target_codesign "${prefpane_path}"
    bt_exit_on_error "Failed to sign preference pane"
}

function prefpane_install
{
    local -a arguments=()
    bt_target_getopt -p install -o arguments -- "${@}"

    local target_directory="${arguments[0]}"
    if [[ ! -d "${target_directory}" ]]
    then
        bt_error "Target directory '${target_directory}' does not exist"
    fi

    bt_log "Install target"

    local prefpane_source_path=""
    prefpane_source_path="`osxfuse_find "${BT_TARGET_BUILD_DIRECTORY}"/*.prefPane`"
    bt_exit_on_error "Failed to locate preference pane"

    bt_target_install "${prefpane_source_path}" "${target_directory}"
    bt_exit_on_error "Failed to install target"
}


# Defaults

declare -ra BT_TARGET_ACTIONS=("build" "clean" "install")
declare     BT_TARGET_SOURCE_DIRECTORY="${BT_SOURCE_DIRECTORY}/prefpane"
