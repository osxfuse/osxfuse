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


declare -ra BUILD_TARGET_ACTIONS=("build" "clean" "install")

declare -a  DISTRIBUTION_KEXT_TASKS=()


function distribution_create_stage_core
{
    local stage_directory="${1}"
    common_assert "[[ -n `string_escape "${stage_directory}"` ]]"

    /bin/mkdir -p "${stage_directory}" \
                  "${stage_directory}/Library/Filesystems" \
                  "${stage_directory}/Library/Frameworks" \
                  "${stage_directory}/usr/local/include" \
                  "${stage_directory}/usr/local/lib" \
                  "${stage_directory}/usr/local/lib/pkgconfig" 1>&3 2>&4
}

function distribution_create_stage_prefpane
{
    local stage_directory="${1}"
    common_assert "[[ -n `string_escape "${stage_directory}"` ]]"

    /bin/mkdir -p "${stage_directory}" \
                  "${stage_directory}/Library/PreferencePanes" 1>&3 2>&4
}

function distribution_build
{
    function distribution_build_getopt_handler
    {
        case "${1}" in
            --kext)
                DISTRIBUTION_KEXT_TASKS+=("${2}")
                return 2
                ;;
        esac
    }

    build_target_getopt -p build -s "kext:" -h distribution_build_getopt_handler -- "${@}"
    unset distribution_build_getopt_handler

    common_log_variable DISTRIBUTION_KEXT_TASKS

    common_log "Clean target"
    build_target_invoke "${BUILD_TARGET_NAME}" clean
    common_die_on_error "Failed to clean target"

    common_log "Build target for OS X ${BUILD_TARGET_OPTION_DEPLOYMENT_TARGET}"

    local -a default_build_options=("-s${BUILD_TARGET_OPTION_SDK}"
                                    "-x${BUILD_TARGET_OPTION_XCODE}"
                                    "${BUILD_TARGET_OPTION_ARCHITECTURES[@]/#/-a}"
                                    "-d${BUILD_TARGET_OPTION_DEPLOYMENT_TARGET}"
                                    "-c${BUILD_TARGET_OPTION_BUILD_CONFIGURATION}"
                                    "${BUILD_TARGET_OPTION_BUILD_SETTINGS[@]/#/-b}"
                                    "${BUILD_TARGET_OPTION_MACROS[@]/#/-m}"
                                    "--code-sign-identity=${BUILD_TARGET_OPTION_CODE_SIGN_IDENTITY}"
                                    "--product-sign-identity=${BUILD_TARGET_OPTION_PRODUCT_SIGN_IDENTITY}")

    local -a library_build_options=("-s${BUILD_TARGET_OPTION_SDK}"
                                    "-x${BUILD_TARGET_OPTION_XCODE}"
                                    "${BUILD_TARGET_OPTION_ARCHITECTURES[@]/#/-a}"
                                    "-d${BUILD_TARGET_OPTION_DEPLOYMENT_TARGET}"
                                    "${BUILD_TARGET_OPTION_MACROS[@]/#/-m}"
                                    "--code-sign-identity=${BUILD_TARGET_OPTION_CODE_SIGN_IDENTITY}"
                                    "--product-sign-identity=${BUILD_TARGET_OPTION_PRODUCT_SIGN_IDENTITY}")

    local stage_directory_core="${BUILD_TARGET_BUILD_DIRECTORY}/Core"
    local stage_directory_prefpane="${BUILD_TARGET_BUILD_DIRECTORY}/PrefPane"
    local debug_directory="${BUILD_TARGET_BUILD_DIRECTORY}/Debug"
    local packages_directory="${BUILD_TARGET_BUILD_DIRECTORY}/Packages"

    /bin/mkdir -p "${BUILD_TARGET_BUILD_DIRECTORY}" 1>&3 2>&4
    common_die_on_error "Failed to create build directory"

    distribution_create_stage_core "${stage_directory_core}"
    common_die_on_error "Failed to create core stage"

    distribution_create_stage_prefpane "${stage_directory_prefpane}"
    common_die_on_error "Failed to create preference pane stage"

    /bin/mkdir -p "${debug_directory}" 1>&3 2>&4
    common_die_on_error "Failed to create debug directory"

    /bin/mkdir -p "${packages_directory}" 1>&3 2>&4
    common_die_on_error "Failed to create packages directory"

    local -a component_packages=()

    # Build file system bundle

    build_target_invoke fsbundle build "${default_build_options[@]}" "${DISTRIBUTION_KEXT_TASKS[@]/#/--kext=}"
    common_die_on_error "Failed to build file system bundle"

    build_target_invoke fsbundle install --debug="${debug_directory}" -- "${stage_directory_core}/Library/Filesystems"
    common_die_on_error "Failed to install file system bundle"

    # Locate file system bundle

    local fsbundle_path=""
    fsbundle_path="`osxfuse_find "${stage_directory_core}/Library/Filesystems"/*.fs`"
    common_die_on_error "Failed to locate file system bundle"

    # Set kernel extension loader SUID bit

    local loader_path=""
    loader_path="`osxfuse_find "${fsbundle_path}/Contents/Resources"/load_*`"
    common_die_on_error "Failed to locate kernel extension loader"

    /bin/chmod u+s "${loader_path}"
    common_die_on_error "Failed to set SUID bit of kernel extension loader"

    # Add embedded uninstaller to file system bundle

    local uninstaller_path="${fsbundle_path}/Contents/Resources/uninstall_osxfuse.app"

    /bin/cp -R "${BUILD_SOURCE_DIRECTORY}/support/uninstall_osxfuse.app" "${uninstaller_path}" 1>&3 2>&4
    common_die_on_error "Failed to copy embedded uninstaller to file system bundle"

    build_target_codesign --deep "${uninstaller_path}"
    common_die_on_error "Failed to sign embedded uninstaller"

    # Sign file system bundle

    build_target_codesign "${fsbundle_path}"
    common_die_on_error "Failed to sign file system bundle"

    # Build library

    build_target_invoke library build "${library_build_options[@]}"
    common_die_on_error "Failed to build library"

    build_target_invoke library install --debug="${debug_directory}" -- "${stage_directory_core}"
    common_die_on_error "Failed to install library"

    /bin/ln -s "libosxfuse.2.dylib" "${stage_directory_core}/usr/local/lib/libosxfuse_i64.2.dylib" && \
    /bin/ln -s "libosxfuse.dylib" "${stage_directory_core}/usr/local/lib/libosxfuse_i64.dylib" && \
    /bin/ln -s "libosxfuse.la" "${stage_directory_core}/usr/local/lib/libosxfuse_i64.la" && \
    /bin/ln -s "osxfuse.pc" "${stage_directory_core}/usr/local/lib/pkgconfig/fuse.pc"
    common_die_on_error "Failed to create legacy library links"

    # Build framework

    build_target_invoke framework build "${default_build_options[@]}" --library-prefix="${stage_directory_core}/usr/local"
    common_die_on_error "Failed to build framework"

    build_target_invoke framework install --debug="${debug_directory}" -- "${stage_directory_core}/Library/Frameworks"
    common_die_on_error "Failed to install framework"

    # Build core component package

    common_log -v 3 "Build core component package"

    osxfuse_build_component_package -n Core -r "${stage_directory_core}" "${packages_directory}/Core.pkg"
    common_die_on_error "Failed to build core package"
    component_packages+=("${packages_directory}/Core.pkg")

    # Build preference pane

    build_target_invoke prefpane build "${default_build_options[@]}"
    common_die_on_error "Failed to build preference pane"

    build_target_invoke prefpane install -- "${stage_directory_prefpane}/Library/PreferencePanes"
    common_die_on_error "Failed to install preference pane"

    # Build preference pane component package

    common_log -v 3 "Build preference pane component package"

    osxfuse_build_component_package -n PrefPane -r "${stage_directory_prefpane}" "${packages_directory}/PrefPane.pkg"
    common_die_on_error "Failed to build preference pane package"
    component_packages+=("${packages_directory}/PrefPane.pkg")

    # Build distribution package

    common_log -v 3 "Build distribution package"

    local distribution_package_path="${BUILD_TARGET_BUILD_DIRECTORY}/Distribution.pkg"

    local -a osx_versions_supported=()
    for task in "${DISTRIBUTION_KEXT_TASKS[@]}"
    do
        local osx_version="`expr "${task}" : '^\([[:digit:]]\{1,\}\(\.[[:digit:]]\{1,\}\)*\)'`"
        version_compare "${osx_version}" "${BUILD_TARGET_OPTION_DEPLOYMENT_TARGET}"
        if (( ${?} != 1 ))
        then
            osx_versions_supported+=("${osx_version}")
        fi
    done

    pushd "${BUILD_TARGET_BUILD_DIRECTORY}" > /dev/null 2>&1
    common_die_on_error "Build directory '${BUILD_TARGET_BUILD_DIRECTORY}' does not exist"

    osxfuse_build_distribution_package -p "${packages_directory}" \
                                       "${component_packages[@]/#/-c}" \
                                       "${osx_versions_supported[@]/#/-d}" \
                                       "${distribution_package_path}"
    common_die_on_error "Failed to build distribution package"

    popd > /dev/null 2>&1
}

function distribution_install
{
    local -a arguments=()
    build_target_getopt -p install -o arguments -- "${@}"

    local target_directory="${arguments[0]}"
    if [[ ! -d "${target_directory}" ]]
    then
        common_die "Target directory '${target_directory}' does not exist"
    fi

    common_log "Install target"

    local distribution_source_path=""
    distribution_source_path="`osxfuse_find "${BUILD_TARGET_BUILD_DIRECTORY}/Distribution.pkg"`"
    common_die_on_error "Failed to locate distribution package"

    build_target_install "${distribution_source_path}" "${target_directory}"
    common_die_on_error "Failed to install target"

    if [[ -n "${BUILD_TARGET_OPTION_DEBUG_DIRECTORY}" ]]
    then
        build_target_install "${BUILD_TARGET_BUILD_DIRECTORY}/Debug/" "${BUILD_TARGET_OPTION_DEBUG_DIRECTORY}"
        common_die_on_error "Failed to Install debug files"
    fi
}
