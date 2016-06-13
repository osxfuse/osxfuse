#!/bin/bash

# Copyright (c) 2011-2016 Benjamin Fleischer
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


function build_target_get_build_directory
{
    local target_name="${1}"

    printf "%s/%s" "${BUILD_BUILD_DIRECTORY}" "${target_name}"
}

function build_target_sanity_check
{
    if ! xcode_sdk_is_supported "${BUILD_TARGET_OPTION_SDK}"
    then
        common_die "macOS ${BUILD_TARGET_OPTION_SDK} SDK not supported"
    fi
    if ! xcode_sdk_is_installed "${BUILD_TARGET_OPTION_SDK}"
    then
        common_die "macOS ${BUILD_TARGET_OPTION_SDK} SDK not found"
    fi

    if ! array_contains "XCODE_INSTALLED" "${BUILD_TARGET_OPTION_XCODE}"
    then
        common_die "Xcode ${BUILD_TARGET_OPTION_XCODE} not found"
    fi
    if ! xcode_contains_sdk "${BUILD_TARGET_OPTION_XCODE}" "${BUILD_TARGET_OPTION_SDK}"
    then
        common_die "Xcode ${BUILD_TARGET_OPTION_XCODE} does not include macOS ${BUILD_TARGET_OPTION_SDK} SDK"
    fi

    function build_target_sanity_check_build_achitecture
    {
        if ! array_contains "DEFAULT_SDK_${BUILD_TARGET_OPTION_SDK/./_}_ARCHITECURES" "${1}"
        then
            common_die "macOS ${BUILD_TARGET_OPTION_SDK} SDK does not support architecture ${1}"
        fi
    }
    array_foreach BUILD_TARGET_OPTION_ARCHITECTURES build_target_sanity_check_build_achitecture
    unset build_target_sanity_check_build_achitecture

    if ! version_is_version "${BUILD_TARGET_OPTION_DEPLOYMENT_TARGET}"
    then
        common_die "Deployment target is illegal"
    fi
    version_compare "${BUILD_TARGET_OPTION_DEPLOYMENT_TARGET}" 10.0
    if (( ${?} == 1 ))
    then
        common_die "Deployment target must be at least macOS 10.0"
    fi
    version_compare "${BUILD_TARGET_OPTION_DEPLOYMENT_TARGET}" "${BUILD_TARGET_OPTION_SDK}"
    if (( ${?} == 2 ))
    then
        common_die "macOS ${BUILD_TARGET_OPTION_SDK} SDK does not support macOS ${BUILD_TARGET_OPTION_DEPLOYMENT_TARGET} as deployment target"
    fi

    if [[ -n "${BUILD_TARGET_OPTION_DEBUG_DIRECTORY}" && ! -d "${BUILD_TARGET_OPTION_DEBUG_DIRECTORY}" ]]
    then
        common_die "Debug directory '${BUILD_TARGET_OPTION_DEBUG_DIRECTORY}' does not exist"
    fi
}

function build_target_getopt
{
    function build_target_getopt_internal
    {
        local -a options=()

        common_getopt options "p:,preset:,s:,custom-specs:,h:,handler:,o:,out:" "${@}"
        common_die_on_error "${options[@]}"

        set -- "${options[@]}"

        local preset=""
        local custom_specs=""
        local handler=""
        local out=""

        while [[ ${#} -gt 0 ]]
        do
            case "${1}" in
                --)
                    shift
                    break
                    ;;
                -p|--preset)
                    preset="${2}"
                    shift 2
                    ;;
                -s|--custom-specs)
                    custom_specs="${2}"
                    shift 2
                    ;;
                -h|--handler)
                    handler="${2}"
                    shift 2
                    ;;
                -o|--out)
                    out="${2}"
                    shift 2
                    ;;
            esac
        done

        if [[ -n "${out}" ]]
        then
            common_assert "common_is_variable `string_escape "${out}"`"
        fi

        local preset_specs=""
        case "${preset}" in
            build)
                preset_specs="s:,sdk:,x:,xcode:,a:,architecure:,d:,deployment-target:,c:,configuration:,b:,build-setting:,m:,macro:,code-sign-identity:,product-sign-identity:"
                ;;
            clean)
                preset_specs="root,no-root"
                ;;
            install)
                preset_specs="root,no-root,o:,owner:,g:,group:,debug:"
                ;;
            make-build)
                preset_specs="s:,sdk:,x:,xcode:,a:,architecure:,d:,deployment-target:,m:,macro:,code-sign-identity:,product-sign-identity:,prefix:"
                ;;
            make-install)
                preset_specs="prefix:,root,no-root,debug:"
                ;;
            meta)
                preset_specs=""
                ;;
        esac

        local specs=""
        if [[ -n "${preset_specs}" && -n "${custom_specs}" ]]
        then
            specs="${preset_specs},${custom_specs}"
        else
            specs="${preset_specs}${custom_specs}"
        fi

        common_getopt options "${specs}" "${@:1}"
        common_die_on_error "${options[@]}"

        set -- "${options[@]}"

        local    sdk=""
        local    xcode=""
        local -a architectures=()
        local    deployment_target=""
        local    build_configuration=""
        local -a build_settings=()
        local -a macros=()

        while [[ ${#} -gt 0 ]]
        do
            case "${1}" in
                --)
                    shift
                    break
                    ;;
                -s|--sdk)
                    sdk="${2}"
                    shift 2
                    ;;
                -x|--xcode)
                    xcode="${2}"
                    shift 2
                    ;;
                -a|--architecture)
                    if ! array_contains architectures "${2}"
                    then
                        array_append architectures "${2}"
                    fi
                    shift 2
                    ;;
                -d|--deployment-target)
                    deployment_target="${2}"
                    shift 2
                    ;;
                -c|--configuration)
                    build_configuration="${2}"
                    shift 2
                    ;;
                -b|--build-setting)
                    if ! array_contains build_settings "${2}"
                    then
                        array_append build_settings "${2}"
                    fi
                    shift 2
                    ;;
                -m|--macro)
                    array_append macros "${2}"
                    shift 2
                    ;;
                --code-sign-identity)
                    BUILD_TARGET_OPTION_CODE_SIGN_IDENTITY="${2}"
                    shift 2
                    ;;
                --product-sign-identity)
                    BUILD_TARGET_OPTION_PRODUCT_SIGN_IDENTITY="${2}"
                    shift 2
                    ;;
                --prefix)
                    BUILD_TARGET_OPTION_PREFIX="${2}"
                    shift 2
                    ;;
                --root)
                    BUILD_TARGET_OPTION_ROOT=1
                    shift
                    ;;
                --no-root)
                    BUILD_TARGET_OPTION_ROOT=0
                    shift
                    ;;
                -o|--owner)
                    BUILD_TARGET_OPTION_OWNER="${2}"
                    shift 2
                    ;;
                -g|--group)
                    BUILD_TARGET_OPTION_GROUP="${2}"
                    shift 2
                    ;;
                --debug)
                    BUILD_TARGET_OPTION_DEBUG_DIRECTORY="${2}"
                    shift 2
                    ;;
                *)
                    if common_is_function "${handler}"
                    then
                        local -i offset=0
                        "${handler}" "${@}"
                        offset=${?}
                        common_assert "(( ${offset} > 0 ))" "Option '${1}' unsupported by handler"
                        shift ${offset}
                    else
                        common_die -t "Option handler required"
                    fi
                    ;;
            esac
        done

        if [[ -z "${out}" && ${#} -gt 0 ]]
        then
            common_warn "Action '${BUILD_TARGET_ACTION}' of target '${BUILD_TARGET_NAME}' does not expect any arguments"
        fi

        if [[ -n "${sdk}" ]]
        then
            BUILD_TARGET_OPTION_SDK="${sdk}"
            BUILD_TARGET_OPTION_DEPLOYMENT_TARGET="${sdk}"
        fi

        if [[ -n "${xcode}" ]]
        then
            BUILD_TARGET_OPTION_XCODE="${xcode}"
        elif xcode_sdk_is_installed "${BUILD_TARGET_OPTION_SDK}"
        then
            array_get XCODE_SDK_${BUILD_TARGET_OPTION_SDK//./_}_XCODE 0 BUILD_TARGET_OPTION_XCODE
        fi

        if [[ ${#architectures[@]} -gt 0 ]]
        then
            common_variable_clone architectures BUILD_TARGET_OPTION_ARCHITECTURES
        elif xcode_sdk_is_supported "${BUILD_TARGET_OPTION_SDK}"
        then
            common_variable_clone DEFAULT_SDK_${BUILD_TARGET_OPTION_SDK//./_}_ARCHITECURES BUILD_TARGET_OPTION_ARCHITECTURES
        fi

        if [[ -n "${deployment_target}" ]]
        then
            BUILD_TARGET_OPTION_DEPLOYMENT_TARGET="${deployment_target}"
        fi

        if [[ -n "${build_configuration}" ]]
        then
            BUILD_TARGET_OPTION_BUILD_CONFIGURATION="${build_configuration}"
        fi

        if [[ ${#build_settings[@]} -gt 0 ]]
        then
            common_variable_clone build_settings BUILD_TARGET_OPTION_BUILD_SETTINGS
        fi

        if [[ ${#macros[@]} -gt 0 ]]
        then
            common_variable_clone macros BUILD_TARGET_OPTION_MACROS
        fi

        if [[ -n "${out}" ]]
        then
            local -a arguments=("${@}")

            printf "%s=" "${out}"
            common_variable_clone arguments
            printf "\n"
        fi

        local target_name_uppercase="`string_uppercase <<< "${BUILD_TARGET_NAME}"`"
        for variable in ${!BUILD_TARGET_OPTION_@} `common_variable_expand "${target_name_uppercase}_"`
        do
            if ! common_variable_is_readonly "${variable}"
            then
                common_variable_print "${variable}"
            fi
        done

        return 0
    }

    eval "`build_target_getopt_internal "${@}"`"
    unset build_target_getopt_internal

    common_log_variable ${!BUILD_TARGET_OPTION_@}
    build_target_sanity_check

    DEVELOPER_DIR="`xcode_get_path "${BUILD_TARGET_OPTION_XCODE}"`"
    export DEVELOPER_DIR
}

function build_target_xcodebuild
{
    local compiler=""
    common_variable_clone "DEFAULT_SDK_${BUILD_TARGET_OPTION_SDK//./_}_COMPILER" compiler

    local -a command=(/usr/bin/xcodebuild
                      -configuration "${BUILD_TARGET_OPTION_BUILD_CONFIGURATION}"
                      CONFIGURATION_BUILD_DIR="`build_target_get_build_directory "${BUILD_TARGET_NAME}"`"
                      SDKROOT="macosx${BUILD_TARGET_OPTION_SDK}"
                      ARCHS="`array_join BUILD_TARGET_OPTION_ARCHITECTURES " "`"
                      GCC_VERSION="${compiler}"
                      MACOSX_DEPLOYMENT_TARGET="${BUILD_TARGET_OPTION_DEPLOYMENT_TARGET}"
                      CODE_SIGN_IDENTITY="${BUILD_TARGET_OPTION_CODE_SIGN_IDENTITY}"
                      "${BUILD_TARGET_OPTION_BUILD_SETTINGS[@]}")
    if [[ ${#BUILD_TARGET_OPTION_MACROS} -gt 0 ]]
    then
        command+=(GCC_PREPROCESSOR_DEFINITIONS="\$(inherited)`printf " %q" "${BUILD_TARGET_OPTION_MACROS[@]}"`")
    fi
    command+=("${@}")

    "${command[@]}" 1>&3 2>&4
}

function build_target_configure
{
    local sdk_path="`xcodebuild -version -sdk macosx${BUILD_TARGET_OPTION_SDK} Path 2>&4`"
    if [[ "${sdk_path}" =~ [[:space:]] ]]
    then
        common_die "macOS ${BUILD_TARGET_OPTION_SDK} SDK path '${sdk_path}' contains whitespace"
    fi

    local compiler=""
    common_variable_clone "DEFAULT_SDK_${BUILD_TARGET_OPTION_SDK//./_}_COMPILER" compiler

    local compiler_binary=""
    case "${compiler}" in
        4.0|4.2)
            compiler_binary="gcc-${compiler}"
            ;;
        com.apple.compilers.llvmgcc42)
            compiler_binary="llvm-gcc-4.2"
            ;;
        com.apple.compilers.llvm.clang.1_0)
            compiler_binary="clang"
            ;;
        *)
            common_die "Compiler '${compiler}' is not supported"
            ;;
    esac

    for macro in "${BUILD_TARGET_OPTION_MACROS[@]}"
    do
        common_assert "[[ `string_escape "${macro}"` =~ ^[^[:space:]]*$ ]]" "Macro '${macro//\'/\\\'}' contains whitespace"
    done

    MAKE="`/usr/bin/xcrun --find make`" \
    CPP="`/usr/bin/xcrun --find cpp`" \
    CC="`/usr/bin/xcrun --find "${compiler_binary}"`" \
    LD="`/usr/bin/xcrun --find ld`" \
    CPPFLAGS="-Wp,-isysroot,${sdk_path} ${CPPFLAGS}" \
    CFLAGS="${BUILD_TARGET_OPTION_ARCHITECTURES[@]/#/-arch } -isysroot ${sdk_path} -mmacosx-version-min=${BUILD_TARGET_OPTION_DEPLOYMENT_TARGET}${BUILD_TARGET_OPTION_MACROS[@]/#/ -D} ${CFLAGS}" \
    LDFLAGS="-Wl,-syslibroot,${sdk_path} -Wl,-macosx_version_min,${BUILD_TARGET_OPTION_DEPLOYMENT_TARGET} ${LDFLAGS}" \
    ./configure --prefix="${BUILD_TARGET_OPTION_PREFIX}" "${@}" 1>&3 2>&4
}

function build_target_make
{
    local -a options=()
    common_getopt options "root,no-root" "${@}"
    common_die_on_error "${options[@]}"

    set -- "${options[@]}"

    local -i root="${BUILD_TARGET_OPTION_ROOT}"

    while [[ ${#} -gt 0 ]]
    do
        case "${1}" in
            --)
                shift
                break
                ;;
            --root)
                root=1
                shift
                ;;
            --no-root)
                root=0
                shift
                ;;
        esac
    done

    local -a command=(/usr/bin/xcrun make "${@}")
    if (( root == 0 ))
    then
        "${command[@]}" 1>&3 2>&4
    else
        common_sudo "Enter password to run make" "${command[@]}" 1>&3 2>&4
    fi
}

function build_target_codesign
{
    if [[ -n "${BUILD_TARGET_OPTION_CODE_SIGN_IDENTITY}" ]]
    then
        /usr/bin/codesign -s "${BUILD_TARGET_OPTION_CODE_SIGN_IDENTITY}" -f "${@}" 1>&3 2>&4
    else
        return 0
    fi
}

function build_target_pkgbuild
{
    local command=(/usr/bin/pkgbuild)

    if [[ -n "${BUILD_TARGET_OPTION_PRODUCT_SIGN_IDENTITY}" ]]
    then
        command+=(--sign "${BUILD_TARGET_OPTION_PRODUCT_SIGN_IDENTITY}")
    fi

    command+=("${@}")

    "${command[@]}" 1>&3 2>&4
}

function build_target_pkgbuild_component_plist_foreach
{
    common_assert "common_is_function `string_escape "${3}"`"
    common_assert "[[ ! `string_escape "${3}"` =~ ^bt_pkgbuild_component_plist_foreach_ ]]"

    if [[ "`plist_array_size "${1}" "${2}"`" -gt 0 ]]
    then
        eval "
            function build_target_pkgbuild_component_plist_foreach_internal
            {
                while [[ \${#} -gt 0 ]]
                do
                    ${3} `string_escape "${1}"` ${2}:\${1}

                    if /usr/libexec/PlistBuddy -c \"Print '${2}:\${1}:ChildBundles'\" `string_escape "${1}"` > /dev/null 2>&1
                    then
                        build_target_pkgbuild_component_plist_foreach `string_escape "${1}"` \"${2}:\${1}:ChildBundles\" ${3}
                    fi
                    shift
                done
            }
        " && build_target_pkgbuild_component_plist_foreach_internal $(/usr/bin/jot - 0 $(( $(plist_array_size "${1}" "${2}") - 1 )))
    fi
}

function build_target_productbuild
{
    local command=(/usr/bin/productbuild)

    if [[ -n "${BUILD_TARGET_OPTION_PRODUCT_SIGN_IDENTITY}" ]]
    then
        command+=(--sign "${BUILD_TARGET_OPTION_PRODUCT_SIGN_IDENTITY}")
    fi

    command+=("${@}")

    "${command[@]}" 1>&3 2>&4
}

function build_target_install
{
    local -a options=()
    common_getopt options "r,root,o:,owner:,g:,group:" "${@}"
    common_die_on_error "${options[@]}"

    set -- "${options[@]}"

    local -i root="${BUILD_TARGET_OPTION_ROOT}"
    local    owner="${BUILD_TARGET_OPTION_OWNER}"
    local    group="${BUILD_TARGET_OPTION_GROUP}"

    while [[ ${#} -gt 0 ]]
    do
        case "${1}" in
            --)
                shift
                break
                ;;
            -r|--root)
                root=1
                shift
                ;;
            -o|--owner)
                owner="${2}"
                shift 2
                ;;
            -g|--group)
                group="${2}"
                shift 2
                ;;
        esac
    done

    local source="${1}"
    local target_directory="${2}"

    common_assert "[[ -e `string_escape "${source}"` ]]"
    common_assert "[[ -d `string_escape "${target_directory}"` ]]"

    local target="${target_directory}"
    if [[ ! "${source}" =~ /$ ]]
    then
        target="${target}/`basename "${source}"`"
        common_assert "[[ ! -e `string_escape "${target}"` ]]" "Target is already installed"
    fi

    local -a command=(/bin/cp -pPR "${source}" "${target}")
    if (( root == 0 ))
    then
        "${command[@]}" 1>&3 2>&4
    else
        common_sudo "Enter password to install target" "${command[@]}" 1>&3 2>&4
    fi
    common_die_on_error "Failed to install target"

    if [[ -n "${owner}" || -n "${group}" ]]
    then
        common_sudo "Enter password to change owner and/or group of installed target" chown -R "${owner}:${group}" "${target}" 1>&3 2>&4
        common_die_on_error "Failed to change owner and/or group of installed target"
    fi
}

function build_target_invoke
{
    local target_name="${1}"
    local action="${2}"

    local target_path="${BUILD_D_DIRECTORY}/targets/${target_name}.sh"

    common_assert "common_function_is_legal_name `string_escape "${target_name}"`"
    common_assert "[[ -f `string_escape "${target_path}"` ]]" "Target '${target_name}' does not exist"

    (
        eval "
            function ${target_name}_build
            {
                common_die -t \"Action '\${BUILD_TARGET_ACTION}' of target '\${BUILD_TARGET_NAME}' needs to be overridden\"
            }

            function ${target_name}_clean
            {
                build_target_getopt -p clean -- \"\${@}\"

                common_log -v 3 \"Removing target build directory '\${BUILD_TARGET_BUILD_DIRECTORY}'\"

                if [[ -e \"\${BUILD_TARGET_BUILD_DIRECTORY}\" ]]
                then
                    local command=(rm -rf \"\${BUILD_TARGET_BUILD_DIRECTORY}\")
                    if (( BUILD_TARGET_OPTION_ROOT == 0 ))
                    then
                        \"\${command[@]}\" 1>&3 2>&4
                    else
                        common_sudo \"Enter password to remove target build directory\" \"\${command[@]}\" 1>&3 2>&4
                    fi
                fi
            }

            function ${target_name}_help
            {
                build_help

                printf \"Target:   %s\n\n\" \"\${BUILD_TARGET_NAME}\"

                printf \"Actions:\r\"
                for action in \"\${BUILD_TARGET_ACTIONS[@]}\"
                do
                    printf \"\033[10C%s\n\" \"\${action}\"
                done
            }
        "

        declare -r  BUILD_TARGET_NAME="${target_name}"
        declare -r  BUILD_TARGET_PATH="${target_path}"

        declare -r  BUILD_TARGET_ACTION="${action}"
        declare -ra BUILD_TARGET_ACTION_ARGUMENTS=("${@:3}")

        declare -a  BUILD_TARGET_ACTIONS=()
        declare     BUILD_TARGET_SOURCE_DIRECTORY="${BUILD_SOURCE_DIRECTORY}"
        declare     BUILD_TARGET_BUILD_DIRECTORY="`build_target_get_build_directory "${BUILD_TARGET_NAME}"`"

        # Options

        declare     BUILD_TARGET_OPTION_SDK="${DEFAULT_SDK}"
        declare     BUILD_TARGET_OPTION_XCODE=""
        declare -a  BUILD_TARGET_OPTION_ARCHITECTURES=()
        declare     BUILD_TARGET_OPTION_DEPLOYMENT_TARGET="${DEFAULT_SDK}"
        declare     BUILD_TARGET_OPTION_BUILD_CONFIGURATION="${DEFAULT_BUILD_CONFIGURATION}"
        declare -a  BUILD_TARGET_OPTION_BUILD_SETTINGS=()
        declare -a  BUILD_TARGET_OPTION_MACROS=()
        declare     BUILD_TARGET_OPTION_CODE_SIGN_IDENTITY=""
        declare     BUILD_TARGET_OPTION_PRODUCT_SIGN_IDENTITY=""
        declare     BUILD_TARGET_OPTION_PREFIX="${DEFAULT_PREFIX}"
        declare -i  BUILD_TARGET_OPTION_ROOT=0
        declare     BUILD_TARGET_OPTION_OWNER=""
        declare     BUILD_TARGET_OPTION_GROUP=""
        declare     BUILD_TARGET_OPTION_DEBUG_DIRECTORY=""

        array_get XCODE_SDK_${BUILD_TARGET_OPTION_SDK/./_}_XCODE 0 BUILD_TARGET_OPTION_XCODE
        common_variable_clone DEFAULT_SDK_${BUILD_TARGET_OPTION_SDK/./_}_ARCHITECURES BUILD_TARGET_OPTION_ARCHITECTURES

        # Source target

        stack_push COMMON_LOG_PREFIX "T:${BUILD_TARGET_NAME}"

        common_log -v 3 "Source target ${BUILD_TARGET_NAME}"

        source "${target_path}" 1>&3 2>&4
        common_die_on_error "Failed to source target"

        common_assert "array_is_array BUILD_TARGET_ACTIONS"
        common_assert "array_contains BUILD_TARGET_ACTIONS `string_escape "${BUILD_TARGET_ACTION}"`" \
                      "Unsupported target action: '${BUILD_TARGET_ACTION}'"

        declare DEVELOPER_DIR="`xcode_get_path "${BUILD_TARGET_OPTION_XCODE}"`"
        export DEVELOPER_DIR

        # Invoke target action

        pushd "${BUILD_TARGET_SOURCE_DIRECTORY}" > /dev/null 2>&1
        common_warn_on_error "Target source directory '${BUILD_TARGET_SOURCE_DIRECTORY}' does not exist"

        common_log -v 3 "Invoke action ${BUILD_TARGET_ACTION}"

        "${target_name}_${BUILD_TARGET_ACTION}" "${BUILD_TARGET_ACTION_ARGUMENTS[@]}"
        declare -i rc=${?}

        common_log -v 3 "Completed action ${BUILD_TARGET_ACTION}"

        popd > /dev/null 2>&1

        stack_pop COMMON_LOG_PREFIX
        exit ${rc}
    )
}


function build_clean
{
    common_log -v 2 "Removing build directory '${BUILD_BUILD_DIRECTORY}'"
    if [[ -e "${BUILD_BUILD_DIRECTORY}" ]]
    then
        rm -rf "${BUILD_BUILD_DIRECTORY}"
    fi
}

function build_help
{
    local script="`basename "${BASH_SOURCE[0]}"`"

/bin/cat <<EOF
Copyright (c) 2011-2015 Benjamin Fleischer
All rights reserved.

Usage:     ${script} [options ...] (-h|--help)  [(-t|--target) {target name}]
           ${script} [options ...] (-c|--clean) [(-t|--target) {target name}]

           ${script} [options ...] (-t|--target) {target name} [(-a|--action) {action}] -- [action options ...]


Options:   [-v {verbose level}|--verbose={verbose level}]

Installed Xcode versions: `array_join XCODE_INSTALLED ", "`
Installed macOS SDKs:     `array_join XCODE_SDK_INSTALLED ", "`
EOF
}

function build_main
{
    local build_d_directory="`dirname "${BASH_SOURCE[0]}"`/build.d"

    # Source libraries

    local library_path=""
    for library_path in "${build_d_directory}/lib"/*.sh
    do
        if [[ -f "${library_path}" ]]
        then
            source "${library_path}" || return 1
        fi
    done

    common_log_initialize
    common_signal_trap_initialize

    declare -r BUILD_D_DIRECTORY="`common_path_absolute "${build_d_directory}"`"

    # Source defaults

    local defaults_path="${BUILD_D_DIRECTORY}/defaults.sh"

    common_log -v 3 "Source defaults"
    stack_push COMMON_LOG_PREFIX "Defaults"

    source "${defaults_path}" 1>&3 2>&4
    common_die_on_error "Failed to source defaults '${defaults_path}'"

    common_variable_require DEFAULT_SOURCE_DIRECTORY \
                            DEFAULT_BUILD_DIRECTORY \
                            DEFAULT_LOG_VERBOSE \
                            DEFAULT_SDK_SUPPORTED \
                            DEFAULT_SDK \
                            DEFAULT_BUILD_CONFIGURATION \
                            DEFAULT_PREFIX

    stack_pop COMMON_LOG_PREFIX

    # Initialize settings

    BUILD_SOURCE_DIRECTORY="${DEFAULT_SOURCE_DIRECTORY}"
    BUILD_BUILD_DIRECTORY="${DEFAULT_BUILD_DIRECTORY}"

    common_log_set_verbose "${DEFAULT_LOG_VERBOSE}"

    # Parse options

    local -a options=()
    common_getopt options "h,help,c,clean,v:,verbose:,s:,source-directory:,b:,build-directory:,t:,target:,a:,action:" "${@}"
    common_die_on_error "${options[@]}"

    set -- "${options[@]}"

    local -i help=0
    local -i clean=0
    local    verbose=2
    local    target_name=""
    local    action="build"

    while [[ ${#} -gt 0 ]]
    do
        case "${1}" in
            --)
                shift
                break
                ;;
            -h|--help)
                help=1
                shift
                ;;
            -c|--clean)
                clean=1
                shift
                ;;
            -v|--verbose)
                verbose="${2}"
                shift 2
                ;;
            -s|--source-directory)
                BUILD_SOURCE_DIRECTORY="`common_path_absolute "${2}"`"
                shift 2
                ;;
            -b|--build-directory)
                BUILD_BUILD_DIRECTORY="`common_path_absolute "${2}"`"
                shift 2
                ;;
            -t|--target)
                target_name="${2}"
                shift 2
                ;;
            -a|--action)
                action="${2}"
                shift 2
                ;;
        esac
    done

    if ! math_is_integer "${verbose}" || [[ ${verbose} -lt 1 ]]
    then
        common_die "Verbosity must be a positive integer"
    fi
    common_log_set_verbose "${verbose}"

    common_log_variable ${!DEFAULT_@} \
                        BUILD_SOURCE_DIRECTORY \
                        BUILD_BUILD_DIRECTORY

    # Find Xcode installations

    xcode_find

    if [[ ${#XCODE_INSTALLED[@]} -eq 0 ]]
    then
        common_die "No version of Xcode found"
    fi
    if [[ ${#XCODE_SDK_INSTALLED} -eq 0 ]]
    then
        common_die "No supported macOS SDK installed"
    fi

    # Check settings

    if [[ ! -e "${BUILD_SOURCE_DIRECTORY}" ]]
    then
        common_warn "Source directory '${BUILD_SOURCE_DIRECTORY}' does not exist"
    fi

    if [[ -z "${DEFAULT_SDK}" ]] || ! xcode_sdk_is_installed "${DEFAULT_SDK}"
    then
        if common_variable_is_readonly DEFAULT_SDK
        then
            common_die "Default macOS SDK not available"
        else
            local macos_version="`macos_get_version`"

            function build_main_default_sdk
            {
                if [[ -z "${DEFAULT_SDK}" ]]
                then
                    DEFAULT_SDK="${1}"
                else
                    version_compare "${1}" "${macos_version}"
                    if (( ${?} == 2 ))
                    then
                        return 1
                    else
                        DEFAULT_SDK="${1}"
                    fi
                fi
            }

            DEFAULT_SDK=""
            array_foreach XCODE_SDK_INSTALLED build_main_default_sdk

            unset build_main_default_sdk

            common_assert "[[ -n `string_escape "${DEFAULT_SDK}"` ]]"
            common_warn "Falling back to macOS ${DEFAULT_SDK} SDK as default SDK"
        fi
    fi

    local variable=""
    for variable in BUILD_SOURCE_DIRECTORY BUILD_BUILD_DIRECTORY ${!DEFAULT_@}
    do
        readonly ${variable}
    done

    # Source extensions

    local extension_path=""
    for extension_path in "${BUILD_D_DIRECTORY}/extensions"/*.sh
    do
        if [[ -f "${library_path}" ]]
        then
            local extension_basename="`basename "${extension_path}"`"
            local extension_name="${extension_basename%.*}"

            common_log -v 3 "Source extension ${extension_name}"

            stack_push COMMON_LOG_PREFIX "E:${extension_name}"

            source "${extension_path}" 1>&3 2>&4
            common_die_on_error "Failed to source extension '${extension_path}'"

            stack_pop COMMON_LOG_PREFIX
        fi
    done

    # Invoke target action

    pushd "${BUILD_SOURCE_DIRECTORY}" > /dev/null 2>&1
    common_warn_on_error "Source directory '${BUILD_SOURCE_DIRECTORY}' does not exist"

    if (( help != 0 ))
    then
        if [[ -n "${target_name}" ]]
        then
            action="help"
        else
            build_help
        fi
    elif (( clean != 0 ))
    then
        if [[ -n "${target_name}" ]]
        then
            action="clean"
        else
            build_clean
        fi
    elif [[ -z "${target_name}" ]]
    then
        common_die "No target specified"
    fi

    if [[ -n "${target_name}" ]]
    then
        build_target_invoke "${target_name}" "${action}" "${@}"
        common_die_on_error "Action '${action}' of target '${target_name}' failed"
    fi

    popd > /dev/null 2>&1
    return 0
}

build_main "${@}"
