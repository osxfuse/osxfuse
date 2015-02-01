#!/bin/bash

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

# Requires array.sh
# Requires common.sh
# Requires string.sh
# Requires version.sh


declare -a XCODE_INSTALLED=()
declare -a XCODE_SDK_INSTALLED=()


function xcode_find
{
    local xcode_app_path=""
    local xcode_path=""

    function xcode_find_sdk_add
    {
        if ! array_contains XCODE_SDK_INSTALLED "${1}"
        then
            array_create "XCODE_SDK_${1/./_}_XCODE"
            array_append XCODE_SDK_INSTALLED "${1}"
        fi

        array_append "XCODE_SDK_${1/./_}_XCODE" "${xcode_version}"
    }

    function xcode_find_process
    {
        local xcode_path="${1}"
        local xcode_version=""

        local sdk_name=""
        local sdk_version=""

        if [[ "${xcode_path}" =~ " " ]]
        then
            common_warn "Skipped Xcode at path '${xcode_path}' (Path contains whitespace)"
            return
        fi
        if [[ -L "${xcode_path}" ]]
        then
            common_warn "Skipped Xcode at path '${xcode_path}' (Path is a symbolic link)"
            return
        fi

        xcode_version="`DEVELOPER_DIR="${xcode_path}" xcodebuild -version 2> /dev/null | grep "Xcode" | /usr/bin/cut -f 2 -d " "`"
        if ! version_is_version "${xcode_version}"
        then
            common_warn "Failed to parse version of Xcode at path '${xcode_path}'"
            return
        fi
        if array_contains XCODE_INSTALLED "${xcode_version}"
        then
            common_warn "Skipped Xcode at path '${xcode_path}' (Duplicate version of Xcode ${xcode_version})"
            return
        fi
        common_log -v 3 "Xcode ${xcode_version} found at path '${xcode_path}'"

        common_variable_set "XCODE_${xcode_version//./_}_PATH" "${xcode_path}"
        array_create "XCODE_${xcode_version//./_}_SDKS"

        for sdk_name in `DEVELOPER_DIR="${xcode_path}" xcodebuild -showsdks | /usr/bin/sed -E -n -e 's/.*-sdk (macosx.*)/\1/p'`
        do
            sdk_version="`DEVELOPER_DIR="${xcode_path}" xcodebuild -version -sdk ${sdk_name} SDKVersion`"
            if ! version_is_version "${sdk_version}"
            then
                continue
            fi
            array_append "XCODE_${xcode_version//./_}_SDKS" "${sdk_version}"
        done

        array_append XCODE_INSTALLED "${xcode_version}"
        array_foreach "XCODE_${xcode_version//./_}_SDKS" xcode_find_sdk_add
    }

    common_log -v 3 "Search for Xcode"

    for xcodebuild_path in /*/usr/bin/xcodebuild
    do
        if [[ ! -e  "${xcodebuild_path}" ]]
        then
            continue
        fi

        xcode_path=`/bin/expr "${xcodebuild_path}" : '^\(\/[^\/]\{1,\}\)\/usr\/bin\/xcodebuild$'`
        xcode_find_process "${xcode_path}"
    done

    while read -r xcode_app_path
    do
        xcode_path="${xcode_app_path}/Contents/Developer"
        xcode_find_process "${xcode_path}"
    done < <(mdfind -onlyin "/Applications" 'kMDItemCFBundleIdentifier == "com.apple.dt.Xcode"')

    unset -f xcode_find_is_supported
    unset -f xcode_find_sdk_add
    unset -f xcode_find_process

    array_sort "XCODE_SDK_INSTALLED" version_compare

    function xcode_find_sdk_sort
    {
        array_sort "XCODE_SDK_${1//./_}_XCODE" version_compare !
    }
    array_foreach XCODE_SDK_INSTALLED xcode_find_sdk_sort
    unset -f xcode_find_sdk_sort

    function xcode_find_print_xcode
    {
        common_log_variable "XCODE_${1//./_}_PATH"
    }
    array_foreach XCODE_INSTALLED xcode_find_print_xcode
    unset -f xcode_find_print_xcode

    common_log_variable XCODE_INSTALLED

    function xcode_find_print_sdk
    {
        common_log_variable "XCODE_SDK_${1//./_}_XCODE"
    }
    array_foreach XCODE_SDK_INSTALLED xcode_find_print_sdk
    unset -f xcode_find_print_sdk

    common_log_variable XCODE_SDK_INSTALLED

    common_log -v 3 "Done searching for Xcode"
}

function xcode_get_path
{
    local xcode_version="${1}"

    local variable="XCODE_${xcode_version//./_}_PATH"
    common_assert "common_is_variable `string_escape "${variable}"`"

    printf "%s" "${!variable}"
}

function xcode_contains_sdk
{
    local xcode_version="${1}"
    local sdk_version="${2}"

    common_assert "version_is_version `string_escape "${xcode_version}"`"
    common_assert "version_is_version `string_escape "${sdk_version}"`"

    local variable="XCODE_SDK_${sdk_version/./_}_XCODE"

    common_is_variable `string_escape "${variable}"` && \
    array_contains "${variable}" "${xcode_version}"
}

function xcode_sdk_is_supported
{
    local sdk_version="${1}"

    common_assert "version_is_version `string_escape "${sdk_version}"`"

    array_contains DEFAULT_SDK_SUPPORTED "${sdk_version}"
}

function xcode_sdk_is_installed
{
    local sdk_version="${1}"

    common_assert "version_is_version `string_escape "${sdk_version}"`"

    array_contains XCODE_SDK_INSTALLED "${sdk_version}"
}

function xcode_sdk_get_path
{
    local -a options=()
    common_getopt options "x:,xcode:,s:,sdk:" "${@}"
    common_die_on_error "${options[@]}"

    set -- "${options[@]}"

    local xcode_version=""
    local xcode_path=""
    local sdk_version=""

    while [[ ${#} -gt 0 ]]
    do
        case "${1}" in
            --)
                shift
                break
                ;;
            -x|--xcode)
                xcode_version="${2}"
                shift 2
                ;;
            -s|--sdk)
                sdk_version="${2}"
                shift 2
                ;;
        esac
    done

    common_assert "version_is_version `string_escape "${xcode_version}"`"
    common_assert "version_is_version `string_escape "${sdk_version}"`"

    xcode_path="`xcode_get_path "${xcode_version}"`"
    DEVELOPER_DIR="${xcode_path}" xcodebuild -version -sdk "macosx${sdk_version}" Path
}
