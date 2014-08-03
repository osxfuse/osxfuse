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


declare -a BT_LOG_PREFIX=()
declare -i BT_LOG_VERBOSE=2

declare -a BT_XCODE_INSTALLED=()
declare -a BT_SDK_INSTALLED=()


function bt_log_initialize
{
    bt_log_set_verbose ${BT_LOG_VERBOSE}
}

function bt_log_set_verbose
{
    local verbose="${1}"

    bt_assert "bt_math_is_integer `bt_string_escape "${verbose}"`"
    bt_assert "[[ ${verbose} -gt 0 ]]"

    BT_LOG_VERBOSE=${verbose}

    if (( BT_LOG_VERBOSE > 4 ))
    then
        exec 3>&1
        exec 4>&2
    else
        exec 3> /dev/null
        exec 4> /dev/null
    fi
}

function bt_log
{
    local -a options=()
    bt_getopt options "v:,verbose:,c:,color:,t,trace,o:,offset:" "${@}"
    bt_exit_on_error "${options[@]}"

    set -- "${options[@]}"

    local -i verbose=2
    local    color=""
    local -i trace=0
    local -i trace_offset=0

    while [[ ${#} -gt 0 ]]
    do
        case "${1}" in
            --)
                shift
                break
                ;;
            -v|--verbose)
                verbose="${2}"
                shift 2
                ;;
            -c|--color)
                color="${2}"
                shift 2
                ;;
            -t|--trace)
                trace=1
                shift
                ;;
            -o|--trace-offset)
                trace_offset="${2}"
                shift 2
                ;;
        esac
    done

    if (( verbose > BT_LOG_VERBOSE ))
    then
        return 0
    fi

    if [[ -z "${color}" ]]
    then
        case ${verbose} in
            1|2)
                color="1;30"
                ;;
            4) 
                color="0;37"
                ;;
            [0-9]+) 
                color="0:30"
                ;;
        esac
    fi

    if (( trace == 1 ))
    then
        local -a stack=()
        local -i i=${trace_offset}
        local    caller=""
        local    function=""
        local    file=""
        local    line=""

        while caller="`caller ${i}`"
        do
            function="`/usr/bin/cut -d " " -f 2 <<< "${caller}"`"
            file="`/usr/bin/cut -d " " -f 3- <<< "${caller}"`"
            line="`/usr/bin/cut -d " " -f 1 <<< "${caller}"`"

            bt_array_add stack "at ${function} (${file}, line ${line})"

            (( i++ ))
        done

        set -- "${@}" "${stack[@]}"
    fi

    while [[ ${#} -gt 0 ]]
    do
        if [[ ${#BT_LOG_PREFIX[@]} -gt 0 ]]
        then
            printf "%-20s | " "${BT_LOG_PREFIX}" >&2
        fi
        printf "\033[${color}m%s\033[0m\n" "${1}" >&2
        shift
    done
}

function bt_log_variable
{
    while [[ ${#} -gt 0 ]]
    do
        bt_log -v 4 -- "`bt_variable_print "${1}"`"
        shift
    done
}

function bt_warn
{
    bt_log -v 1 -c "0;31" -o 1 "${@}"
}

function bt_error
{
    if [[ ${#} -eq 0 ]]
    then
        set -- "Unspecified error"
    fi

    bt_log -v 1 -c "1;31" -o 1 "${@}"
    echo -ne "\a" >&2

    if (( BASH_SUBSHELL > 0 ))
    then
        kill -SIGTERM 0
    fi
    exit 1
}

function bt_assert
{
    if [[ -n "${1}" ]]
    then
        eval "${1}"
        if [[ ${?} -ne 0 ]]
        then
            if [[ -n "${2}" ]]
            then
                bt_error -t -o 2 "${2}"
            else
                bt_error -t -o 2 "Assertion '${1}' failed"
            fi
        fi
    fi
}

function bt_exit_on_error
{
    if [[ ${?} -ne 0 ]]
    then
        bt_error "${@}"
    fi
}

function bt_warn_on_error 
{
    if [[ ${?} -ne 0 ]]
    then
        bt_warn "${@}"
    fi
}


function bt_signal_handler
{
    local signal="${1}"

    bt_log -v 4 "Received signal: ${signal}"
    case "${signal}" in
        SIGINT)  
            bt_warn "Aborted by user"
            exit 130
            ;;
        SIGTERM)
            exit 143
            ;;
        *)
            bt_warn "Ignore signal: ${signal}"
            ;;
    esac
}


function bt_getopt
{
	function bt_getopt_internal
	{
        local variable="${1}"

        local -a specs=()
        IFS="," read -ra specs <<< "${2}"

        bt_assert "bt_is_array `bt_string_escape ${variable}`"

        local -i error=0
        local -a out=()

        function bt_getopt_spec
	    {
	        case "${1: -1}" in
	            ":")
	                bt_variable_set "${2}" "${1:0:$((${#1} - 1))}"
	                bt_variable_set "${3}" 1
	                ;;
	            "?")
	                bt_variable_set "${2}" "${1:0:$((${#1} - 1))}"
	                bt_variable_set "${3}" 2
	                ;;
	            *)
	                bt_variable_set "${2}" "${1}"
	                bt_variable_set "${3}" 0
	                ;;
	        esac
	    }

	    local    spec_name=""
	    local -i spec_has_argument=0

	    local    option=""
	    local    option_name=""
	    local    option_argument=""
	    local -i option_has_argument=0

	    local -i match_found=0
	    local    match_name=""
	    local -i match_has_argument=0

        shift 2
	    while [[ ${#} -gt 0 ]]
	    do
	        case ${1} in
	            --)
	                break
	                ;;
	            -)
	                out+=("--")
	                break
	                ;;
	            --*)
		            option="${1:2}"
		            shift

		            option_name="`/usr/bin/sed -E -n -e 's/^([^=]*).*$/\1/p' <<< "${option}"`"
		            option_argument="`/usr/bin/sed -E -n -e 's/^[^=]*=(.*)$/\1/p' <<< "${option}"`"

		            [[ ! "${option}" =~ "=" ]]
		            option_has_argument=${?}

		            match_found=0
		            match_name=""
		            match_has_argument=0
		            for spec in "${specs[@]}"
		            do
		                bt_getopt_spec "${spec}" spec_name spec_has_argument

		                if [[ ${#spec_name} -eq 1 ]]
		                then
		                    continue
		                fi

		                if [[ "${spec_name:0:${#option_name}}" = "${option_name}" ]]
		                then
		                    match_name="${spec_name}"
		                    match_has_argument=${spec_has_argument}

		                    if [[ ${#spec_name} -eq ${#option_name} ]]
		                    then
		                        match_found=1
		                        break
		                    elif (( match_found != 0 ))
		                    then
                                error=1
                                out=("Option '${option_name}' is ambiguous")
                                break 2
		                    else
		                        match_found=1
		                    fi
		                fi
		            done
		            if (( match_found == 0 ))
		            then
                        error=1
                        out=("Illegal option '${option_name}'")
                        break
		            fi
		            if (( match_has_argument != 2 && option_has_argument != match_has_argument ))
		            then
                        error=1
                        if (( option_has_argument == 0 ))
                        then
                            out=("Option '${option_name}' requires an argument")
                        else
                            out=("Option '${option_name}' does not allow an argument")
                        fi
                        break
		            fi

		            out+=("--${match_name}")
		            if (( match_has_argument != 0 ))
		            then
		                out+=("${option_argument}")
		            fi
		        	;;
		        -*)
		            option="${1:1}"
		            shift

		            option_name="${option:0:1}"
		            option_argument="${option:1}"

		            match_found=0
		            for spec in "${specs[@]}"
		            do
		                bt_getopt_spec "${spec}" spec_name spec_has_argument

		                if [[ "${option_name}" = "${spec_name}" ]]
		                then
		                    match_found=1

		                    out+=("-${option_name}")
		                    if (( spec_has_argument == 0 ))
		                    then
		                        if [[ -n "${option_argument}" ]]
		                        then
		                            set -- "-${option_argument}" "${@}"
		                        fi
		                    else
		                        if [[ -z "${option_argument}" ]]
		                        then
		                            if [[ ${#} -le 0 ]]
		                            then
                                        error=1
                                        out=("Option '${option_name}' requires an argument")
                                        break 2
		                            fi
		                            option_argument="${1}"
		                            shift
		                        fi

		                        out+=("${option_argument}")
		                    fi
		                    break
		                fi
		            done

		            if (( match_found == 0 ))
		            then
                        error=1
                        out=("Illegal option '${option_name}'")
                        break
		            fi
		        	;;
		        *)
		            out+=("--")
		            break
		        	;;
	        esac
	    done

        if (( error == 0 ))
        then
            out+=("${@}")
        fi

        printf "%s=%s\n" "${variable}" "`bt_variable_clone out`"
        printf "return %d\n" ${error}
	}

    eval "`bt_getopt_internal "${@}"`"
}

function bt_sudo
{
    local prompt="${1}"

    bt_assert "[[ -n `bt_string_escape "${prompt}"` ]]"
    bt_assert "[[ ${#} -gt 1 ]]"

    if [[ ${#BT_LOG_PREFIX[@]} -gt 0 ]]
    then
        prompt="`printf "%-20s | %s" "${BT_LOG_PREFIX}" "${prompt}"`"
    fi

    sudo -p "${prompt}: " "${@:2}"
}


function bt_is_function
{
    [[ "`type -t "${1}"`" == "function" ]]
}

function bt_function_is_legal_name
{
    [[ "${1}" =~ ^[a-zA-Z_][0-9a-zA-Z_]*$ ]]
}


function bt_is_variable
{
    compgen -A variable | grep ^"${1}"$ > /dev/null
}

function bt_variable_is_legal_name
{
    [[ "${1}" =~ ^[a-zA-Z_][0-9a-zA-Z_]*$ ]]
}

function bt_variable_is_readonly
{
    if bt_is_variable "${1}"
    then
        [[ "`declare -p "${1}" 2> /dev/null`" =~ ^"declare -"[^=]{0,}"r"[^=]{0,}" ${1}=" ]]
    fi
}

function bt_variable_get
{
    bt_assert "bt_is_variable `bt_string_escape "${1}"`"

    bt_string_escape "${!1}"
}

function bt_variable_set
{
    bt_assert "bt_variable_is_legal_name `bt_string_escape "${1}"`"
    
    eval "${1}=`bt_string_escape "${2}"`"
}

function bt_variable_clone
{
    if [[ -z "${2}" ]]
    then
        bt_assert "bt_is_variable `bt_string_escape "${1}"`"

        if bt_is_array "${1}"
        then
            printf "("
            bt_array_get_elements "${1}"
            printf ")"
        else
            bt_variable_get "${1}"
        fi
    else
        bt_assert "bt_variable_is_legal_name `bt_string_escape "${2}"`"

        eval "${2}=`bt_variable_clone "${1}"`"
    fi
}

function bt_variable_print
{
    bt_assert "bt_is_variable `bt_string_escape "${1}"`"

    printf "%s=" "${1}"
    bt_variable_clone "${1}"
    printf "\n"
}

function bt_variable_require
{
    while [[ ${#} -gt 0 ]]
    do
        if ! bt_is_variable "${1}"
        then
            bt_error "Variable not declared: ${1}"
        fi
        shift
    done
}

function bt_variable_expand
{
    while [[ ${#} -gt 0 ]]
    do
        eval "echo \${!${1}_@}"
        shift
    done
}


function bt_string_trim
{
    local string="${1}"

    ! shopt -q extglob
    local -i extglob=${?}

    if (( extglob == 0 ))
    then
        shopt -s extglob
    fi

    string="${string##+([[:space:]])}"
    string="${string%%+([[:space:]])}"

    if (( extglob == 0 ))
    then
        shopt -u extglob
    fi

    printf "%s" "${string}"
}

function bt_string_lowercase
{
    /usr/bin/tr '[A-Z]' '[a-z]'
}

function bt_string_uppercase
{
    /usr/bin/tr '[a-z]' '[A-Z]'
}

function bt_string_escape
{
    local count="${2:-1}"

    if [[ "${count}" =~ [0-9]+ ]] && (( count > 0 ))
    then
        printf "%q" "`bt_string_escape "${1}" $(( ${count} - 1 ))`"
    else
        printf "%s" "${1}"
    fi
}

function bt_string_compare
{
    if [[ "${1}" < "${2}" ]]
    then
        return 1
    fi
    if [[ "${1}" > "${2}" ]]
    then
        return 2
    fi 
    return 0
}


function bt_is_array
{
    if bt_is_variable "${1}"
    then
        [[ "`declare -p "${1}" 2> /dev/null`" =~ ^"declare -"[^=]{0,}"a"[^=]{0,}" ${1}=" ]]
    else
        return 1
    fi
}

function bt_array_create
{
    bt_assert "bt_variable_is_legal_name `bt_string_escape "${1}"`"

    eval "${1}=()"
}

function bt_array_size
{
    bt_assert "bt_is_array `bt_string_escape "${1}"`"

    eval "printf \"%u\" \${#${1}[@]}"
}

function bt_array_get
{
    if [[ -z "${3}" ]]
    then
        bt_assert "bt_is_variable `bt_string_escape "${1}"`"
        bt_assert "bt_math_is_integer `bt_string_escape "${2}"` && [[ ${2} -ge 0 ]]"

        eval "bt_string_escape \"\${${1}[${2}]}\""
    else
        bt_assert "bt_is_variable `bt_string_escape "${3}"`"

        eval "${3}=`bt_array_get "${1}" "${2}"`"
    fi
}

function bt_array_set
{
    bt_assert "bt_is_variable `bt_string_escape "${1}"`"
    bt_assert "bt_math_is_integer `bt_string_escape "${2}"` && [[ ${2} -ge 0 ]]"

    eval "${1}[${2}]=`bt_string_escape "${3}"`"
}

function bt_array_add
{
    bt_assert "bt_is_variable `bt_string_escape "${1}"`"

    eval "${1}+=(`bt_string_escape "${2}"`)"
}

function bt_array_get_elements
{
    bt_assert "bt_is_variable `bt_string_escape "${1}"`"

    function bt_array_get_elements_serialize
    {
        local offset=$(( ${#} / 2 + 1 ))
        
        if [[ ${#} -ge ${offset} ]]
        then
            printf '[%q]=%q' "${1}" "${!offset}"
            shift

            while [[ ${#} -ge ${offset} ]]
            do
                printf ' [%q]=%q' "${1}" "${!offset}"
                shift
            done
        fi
    }
    eval "bt_array_get_elements_serialize \"\${!${1}[@]}\" \"\${${1}[@]}\""

    local rc=${?}
    unset -f bt_array_get_elements_serialize
    return ${rc}
}

function bt_array_foreach
{
    bt_assert "bt_is_variable `bt_string_escape "${1}"`"
    bt_assert "bt_is_function `bt_string_escape "${2}"`"
    bt_assert "[[ ! `bt_string_escape "${2}"` =~ ^bt_array_foreach_ ]]"

    eval "
        function bt_array_foreach_internal
        {
            while [[ \${#} -gt 0 ]]
            do
                if ${2} \"\${1}\"
                then
                    shift
                else
                    return \${?}
                fi
            done
        }

        function bt_array_foreach_wrapper
        {
            bt_array_foreach_internal \"\${${1}[@]}\"
        }
    " && bt_array_foreach_wrapper

    local rc=${?}
    unset -f bt_array_foreach_internal
    unset -f bt_array_foreach_wrapper
    return ${rc}
}

function bt_array_contains
{
    eval "
        function bt_array_contains_compare
        {
            [[ \"\${1}\" != `bt_string_escape "${2}"` ]]
        }
    " && ! bt_array_foreach "${1}" bt_array_contains_compare

    local rc=${?}
    unset -f bt_array_contains_compare
    return ${rc}
}

function bt_array_sort
{
    bt_assert "bt_is_variable `bt_string_escape "${1}"`"
    bt_assert "bt_is_function `bt_string_escape "${2}"`"
    bt_assert "[[ ! `bt_string_escape "${2}"` =~ ^bt_array_sort_ ]]"
    bt_assert "[[ `bt_string_escape "${3}"` =~ !? ]]"

    eval "
        function bt_array_sort_quicksort
        {
            local -a left=()
            local -a right=()
            local    pivot=""

            if [[ \${#} -eq 0 ]]
            then
                return 0
            fi

            pivot=\"\${1}\"
            shift
            
            while [[ \${#} -gt 0 ]]
            do
                ${2} \"\${1}\" \"\${pivot}\"
                if [[ ${3} \${?} -le 1 ]]
                then
                    left[\${#left[@]}]=\"\${1}\"
                else
                    right[\${#right[@]}]=\"\${1}\"
                fi
                shift
            done

            if [[ \${#left[@]} -gt 0 ]]
            then
                bt_array_sort_quicksort \"\${left[@]}\"
            fi
            bt_string_escape \"\${pivot}\"
            printf \"%s\" \"\${IFS}\"
            if [[ \${#right[@]} -gt 0 ]]
            then
                bt_array_sort_quicksort \"\${right[@]}\"
            fi
        }

        function bt_array_sort_wrapper
        {
            eval \"${1}=(\$(bt_array_sort_quicksort \"\${${1}[@]}\"))\"
        }
    " && bt_array_sort_wrapper

    local rc=${?}
    unset -f bt_array_sort_quicksort
    unset -f bt_array_sort_wrapper
    return ${rc}
}

function bt_array_join
{
    bt_assert "bt_is_variable `bt_string_escape "${1}"`"

    eval "
        function bt_array_join_internal
        {
            printf \"%s\" \"\${1}\"
            shift
            while [[ \${#} -gt 0 ]]
            do
                printf \"%s%s\" `bt_string_escape "${2:-, }"` \"\${1}\"
                shift
            done
            printf \"\n\"
        }

        function bt_array_join_wrapper
        {
            bt_array_join_internal \"\${${1}[@]}\"
        }
    " && bt_array_join_wrapper

    local rc=${?}
    unset -f bt_array_join_internal
    unset -f bt_array_join_wrapper
    return ${rc}
}


function bt_stack_push
{
    bt_assert "bt_is_variable `bt_string_escape "${1}"`"

    eval "${1}=(`bt_string_escape "${2}"` \"\${${1}[@]}\")"
    bt_exit_on_error "Stack operation push failed: ${1}"
}

function bt_stack_pop
{
    bt_assert "bt_is_array `bt_string_escape "${1}"`"
    bt_assert "[[ `bt_array_size "${1}"` -gt 0 ]]"

    eval "${1}=(\"\${${1}[@]:1}\")"
    bt_exit_on_error "Stack operation pop failed: ${1}"
}


function bt_path_absolute
{
    local    path="${1}"
    local -a tokens=()
    local -i tokens_count=0
    local -i i=0

    if [[ ! "${path}" =~ ^/ ]]
    then
        path="`pwd -P`/${path}"
    fi
    IFS="/" read -ra tokens <<< "${path}"
    tokens_count=${#tokens[@]}

    for (( i=0 ; i < ${tokens_count} ; i++ ))
    do
        case "${tokens[${i}]}" in
            .|"")
                unset -v tokens[${i}]
                ;;
            ..)
                unset -v tokens[$(( i - 1 ))]
                unset -v tokens[${i}]
                ;;
        esac
    done

    printf "/"
    bt_array_join tokens "/"
}


function bt_math_is_integer
{
    [[ "${1}" =~ ^-?[0-9]+$ ]]
}

function bt_math_compare
{
    if [[ ${1} -lt ${2} ]]
    then
        return 1
    fi
    if [[ ${1} -gt ${2} ]]
    then
        return 2
    fi 
    return 0
}

function bt_math_max
{
    bt_assert "bt_math_is_integer `bt_string_escape "${1}"`"
    bt_assert "bt_math_is_integer `bt_string_escape "${2}"`"

    if [[ ${1} -gt ${2} ]]
    then
        printf "%s" "${1}"
    else
        printf "%s" "${2}"
    fi
}

function bt_math_min
{
    bt_assert "bt_math_is_integer `bt_string_escape "${1}"`"
    bt_assert "bt_math_is_integer `bt_string_escape "${2}"`"

    if [[ ${1} -lt ${2} ]]
    then
        printf "%s" "${1}"
    else
        printf "%s" "${2}"
    fi
}


function bt_is_version
{
    [[ "${1}" =~ ^[0-9]+(\.[0-9]+)*$ ]]
}

function bt_version_compare
{
    bt_assert "bt_is_version `bt_string_escape "${1}"`"
    bt_assert "bt_is_version `bt_string_escape "${2}"`"

    local -a version1=()
    local -a version2=()

    IFS="." read -ra version1 <<< "${1}"
    IFS="." read -ra version2 <<< "${2}"

    local -i i=0
    local    t1=""
    local    t2=""
    for (( i=0 ; i < `bt_math_max ${#version1[@]} ${#version2[@]}` ; i++ ))
    do
        t1=${version1[${i}]:-0}
        t2=${version2[${i}]:-0}

        if (( t1 < t2 ))
        then
            return 1
        fi
        if (( t1 > t2 ))
        then
            return 2
        fi
    done
    return 0
}


function bt_osx_get_version
{
    sw_vers -productVersion | /usr/bin/cut -d . -f 1,2
}


function bt_plist_get
{
    local file="${1}"
    local entry="${2}"

    /usr/libexec/PlistBuddy -x -c "Print '${entry}'" "${file}" 2> /dev/null
}

function bt_plist_set
{
    local file="${1}"
    local entry="${2}"
    local type="${3}"
    local value="${4}"

    /usr/libexec/PlistBuddy -c "Delete '${entry}'" "${file}" > /dev/null 2>&1
    /usr/libexec/PlistBuddy -c "Add '${entry}' '${type}' '${value}'" "${file}" > /dev/null 2>&1
}

function bt_plist_array_size
{
    local file="${1}"
    local entry="${2}"

    bt_plist_get "${file}" "${entry}" | /usr/bin/xpath 'count(/plist/array/*)' 2> /dev/null
}


function bt_xcode_find
{
    local xcode_app_path=""
    local xcode_path=""

    function bt_xcode_find_sdk_add
    {
        if ! bt_array_contains BT_SDK_INSTALLED "${1}"
        then
            bt_array_create "BT_SDK_${1/./_}_XCODE"
            bt_array_add BT_SDK_INSTALLED "${1}"
        fi
        
        bt_array_add "BT_SDK_${1/./_}_XCODE" "${xcode_version}"
    }

    function bt_xcode_find_process
    {
        local xcode_path="${1}"
        local xcode_version=""

        local sdk_name=""
        local sdk_version=""

        if [[ "${xcode_path}" =~ " " ]]
        then
            bt_warn "Skipped Xcode at path '${xcode_path}' (Path contains whitespace)"
            return
        fi
        if [[ -L "${xcode_path}" ]]
        then
            bt_warn "Skipped Xcode at path '${xcode_path}' (Path is a symbolic link)"
            return
        fi

        xcode_version="`DEVELOPER_DIR="${xcode_path}" xcodebuild -version 2> /dev/null | grep "Xcode" | /usr/bin/cut -f 2 -d " "`"
        if ! bt_is_version "${xcode_version}"
        then
            bt_warn "Failed to parse version of Xcode at path '${xcode_path}'"
            return
        fi
        if bt_array_contains BT_XCODE_INSTALLED "${xcode_version}"
        then
            bt_warn "Skipped Xcode at path '${xcode_path}' (Duplicate version of Xcode ${xcode_version})"
            return
        fi
        bt_log -v 3 "Xcode ${xcode_version} found at path '${xcode_path}'"

        bt_variable_set "BT_XCODE_${xcode_version//./_}_PATH" "${xcode_path}"
        bt_array_create "BT_XCODE_${xcode_version//./_}_SDKS"

        for sdk_name in `DEVELOPER_DIR="${xcode_path}" xcodebuild -showsdks | /usr/bin/sed -E -n -e 's/.*-sdk (macosx.*)/\1/p'`
        do
            sdk_version="`DEVELOPER_DIR="${xcode_path}" xcodebuild -version -sdk ${sdk_name} SDKVersion`"
            if ! bt_is_version "${sdk_version}"
            then
                continue
            fi
            bt_array_add "BT_XCODE_${xcode_version//./_}_SDKS" "${sdk_version}"
        done

        bt_array_add BT_XCODE_INSTALLED "${xcode_version}"
        bt_array_foreach "BT_XCODE_${xcode_version//./_}_SDKS" bt_xcode_find_sdk_add
    }

    bt_log -v 3 "Search for Xcode"

    for xcodebuild_path in /*/usr/bin/xcodebuild
    do
        if [[ ! -e  "${xcodebuild_path}" ]]
        then
            continue
        fi

        xcode_path=`/bin/expr "${xcodebuild_path}" : '^\(\/[^\/]\{1,\}\)\/usr\/bin\/xcodebuild$'`
        bt_xcode_find_process "${xcode_path}"
    done

    while read -r xcode_app_path
    do
        xcode_path="${xcode_app_path}/Contents/Developer"
        bt_xcode_find_process "${xcode_path}"
    done < <(mdfind -onlyin "/Applications" 'kMDItemCFBundleIdentifier == "com.apple.dt.Xcode"')

    unset -f bt_xcode_find_is_supported
    unset -f bt_xcode_find_sdk_add
    unset -f bt_xcode_find_process

    bt_array_sort "BT_SDK_INSTALLED" bt_version_compare

    function bt_xcode_find_sdk_sort
    {
        bt_array_sort "BT_SDK_${1//./_}_XCODE" bt_version_compare !
    }
    bt_array_foreach BT_SDK_INSTALLED bt_xcode_find_sdk_sort
    unset -f bt_xcode_find_sdk_sort

    function bt_xcode_find_print_xcode
    {
        bt_log_variable "BT_XCODE_${1//./_}_PATH"
    }
    bt_array_foreach BT_XCODE_INSTALLED bt_xcode_find_print_xcode
    unset -f bt_xcode_find_print_xcode

    bt_log_variable BT_XCODE_INSTALLED

    function bt_xcode_find_print_sdk
    {
        bt_log_variable "BT_SDK_${1//./_}_XCODE"
    }
    bt_array_foreach BT_SDK_INSTALLED bt_xcode_find_print_sdk
    unset -f bt_xcode_find_print_sdk

    bt_log_variable BT_SDK_INSTALLED

    bt_log -v 3 "Done searching for Xcode"
}

function bt_xcode_get_path
{
    local xcode_version="${1}"

    local variable="BT_XCODE_${xcode_version//./_}_PATH"
    bt_assert "bt_is_variable `bt_string_escape "${variable}"`"

    printf "%s" "${!variable}"
}

function bt_xcode_contains_sdk
{
    local xcode_version="${1}"
    local sdk_version="${2}"

    bt_assert "bt_is_version `bt_string_escape "${xcode_version}"`"
    bt_assert "bt_is_version `bt_string_escape "${sdk_version}"`"

    local variable="BT_SDK_${sdk_version/./_}_XCODE"

    bt_is_variable `bt_string_escape "${variable}"` && \
    bt_array_contains "${variable}" "${xcode_version}"
}

function bt_sdk_is_supported
{
    local sdk_version="${1}"

    bt_assert "bt_is_version `bt_string_escape "${sdk_version}"`"

    bt_array_contains BT_SDK_SUPPORTED "${sdk_version}"
}

function bt_sdk_is_installed
{
    local sdk_version="${1}"

    bt_assert "bt_is_version `bt_string_escape "${sdk_version}"`"

    bt_array_contains BT_SDK_INSTALLED "${sdk_version}"
}

function bt_sdk_get_path
{
    local -a options=()
    bt_getopt options "h,help,v:,verbose:,a:,action:" "${@}"
    bt_exit_on_error "${options[@]}"

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

    bt_assert "bt_is_version `bt_string_escape "${xcode_version}"`"
    bt_assert "bt_is_version `bt_string_escape "${sdk_version}"`"

    xcode_path="`bt_xcode_get_path "${xcode_version}"`"
    DEVELOPER_DIR="${xcode_path}" xcodebuild -version -sdk "macosx${sdk_version}" Path
}


function bt_target_get_build_directory
{
    local target_name="${1}"

    printf "%s/%s" "${BT_BUILD_DIRECTORY}" "${target_name}"
}

function bt_target_sanity_check
{
    if ! bt_sdk_is_supported "${BT_TARGET_OPTION_SDK}"
    then
        bt_error "OS X ${BT_TARGET_OPTION_SDK} SDK not supported"
    fi
    if ! bt_sdk_is_installed "${BT_TARGET_OPTION_SDK}"
    then
        bt_error "OS X ${BT_TARGET_OPTION_SDK} SDK not found"
    fi

    if ! bt_array_contains "BT_XCODE_INSTALLED" "${BT_TARGET_OPTION_XCODE}"
    then
        bt_error "Xcode ${BT_TARGET_OPTION_XCODE} not found"
    fi
    if ! bt_xcode_contains_sdk "${BT_TARGET_OPTION_XCODE}" "${BT_TARGET_OPTION_SDK}"
    then
        bt_error "Xcode ${BT_TARGET_OPTION_XCODE} does not include OS X ${BT_TARGET_OPTION_SDK} SDK"
    fi

    function bt_target_sanity_check_build_achitecture
    {
        if ! bt_array_contains "BT_SDK_${BT_TARGET_OPTION_SDK/./_}_ARCHITECURES" "${1}"
        then
            bt_error "OS X ${BT_TARGET_OPTION_SDK} SDK does not support architecture ${1}"
        fi
    }
    bt_array_foreach BT_TARGET_OPTION_ARCHITECTURES bt_target_sanity_check_build_achitecture
    unset bt_target_sanity_check_build_achitecture

    if ! bt_is_version "${BT_TARGET_OPTION_DEPLOYMENT_TARGET}"
    then
        bt_error "Deployment target is illegal"
    fi
    bt_version_compare "${BT_TARGET_OPTION_DEPLOYMENT_TARGET}" 10.0
    if [[ ${?} -eq 1 ]]
    then
        bt_error "Deployment target must be at least OS X 10.0"
    fi
    bt_version_compare "${BT_TARGET_OPTION_DEPLOYMENT_TARGET}" "${BT_TARGET_OPTION_SDK}"
    if [[ ${?} -eq 2 ]]
    then
        bt_error "OS X ${BT_TARGET_OPTION_SDK} SDK does not support OS X ${BT_TARGET_OPTION_DEPLOYMENT_TARGET} as deployment target"
    fi

    if [[ -n "${BT_TARGET_OPTION_DEBUG_DIRECTORY}" && ! -d "${BT_TARGET_OPTION_DEBUG_DIRECTORY}" ]]
    then
        bt_error "Debug directory '${BT_TARGET_OPTION_DEBUG_DIRECTORY}' does not exist"
    fi
}

function bt_target_getopt
{
    function bt_target_getopt_internal
    {
        local -a options=()

        bt_getopt options "p:,preset:,s:,custom-specs:,h:,handler:,o:,out:" "${@}"
        bt_exit_on_error "${options[@]}"

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
            bt_assert "bt_is_variable `bt_string_escape "${out}"`"
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

        bt_getopt options "${specs}" "${@:1}"
        bt_exit_on_error "${options[@]}"

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
                    if ! bt_array_contains architectures "${2}"
                    then
                        bt_array_add architectures "${2}"
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
                    if ! bt_array_contains build_settings "${2}"
                    then
                        bt_array_add build_settings "${2}"
                    fi
                    shift 2
                    ;;
                -m|--macro)
                    bt_array_add macros "${2}"
                    shift 2
                    ;;
                --code-sign-identity)
                    BT_TARGET_OPTION_CODE_SIGN_IDENTITY="${2}"
                    shift 2
                    ;;
                --product-sign-identity)
                    BT_TARGET_OPTION_PRODUCT_SIGN_IDENTITY="${2}"
                    shift 2
                    ;;
                --prefix)
                    BT_TARGET_OPTION_PREFIX="${2}"
                    shift 2
                    ;;
                --root)
                    BT_TARGET_OPTION_ROOT=1
                    shift
                    ;;
                --no-root)
                    BT_TARGET_OPTION_ROOT=0
                    shift
                    ;;
                -o|--owner)
                    BT_TARGET_OPTION_OWNER="${2}"
                    shift 2
                    ;;
                -g|--group)
                    BT_TARGET_OPTION_GROUP="${2}"
                    shift 2
                    ;;
                --debug)
                    BT_TARGET_OPTION_DEBUG_DIRECTORY="${2}"
                    shift 2
                    ;;
                *)
                    if bt_is_function "${handler}"
                    then
                        local -i offset=0
                        "${handler}" "${@}"
                        offset=${?}
                        bt_assert "(( ${offset} > 0 ))" "Option '${1}' unsupported by handler"
                        shift ${offset}
                    else
                        bt_error -t "Option handler required"
                    fi
                    ;;
            esac
        done

        if [[ -z "${out}" && ${#} -gt 0 ]]
        then
            bt_warn "Action '${BT_TARGET_ACTION}' of target '${BT_TARGET_NAME}' does not expect any arguments"
        fi

        if [[ -n "${sdk}" ]]
        then
            BT_TARGET_OPTION_SDK="${sdk}"
            BT_TARGET_OPTION_DEPLOYMENT_TARGET="${sdk}"
        fi

        if [[ -n "${xcode}" ]]
        then
            BT_TARGET_OPTION_XCODE="${xcode}"
        elif bt_sdk_is_installed "${BT_TARGET_OPTION_SDK}"
        then
            bt_array_get BT_SDK_${BT_TARGET_OPTION_SDK//./_}_XCODE 0 BT_TARGET_OPTION_XCODE
        fi

        if [[ ${#architectures[@]} -gt 0 ]]
        then
            bt_variable_clone architectures BT_TARGET_OPTION_ARCHITECTURES
        elif bt_sdk_is_supported "${BT_TARGET_OPTION_SDK}"
        then
            bt_variable_clone BT_SDK_${BT_TARGET_OPTION_SDK//./_}_ARCHITECURES BT_TARGET_OPTION_ARCHITECTURES
        fi

        if [[ -n "${deployment_target}" ]]
        then
            BT_TARGET_OPTION_DEPLOYMENT_TARGET="${deployment_target}"
        fi

        if [[ -n "${build_configuration}" ]]
        then
            BT_TARGET_OPTION_BUILD_CONFIGURATION="${build_configuration}"
        fi

        if [[ ${#build_settings[@]} -gt 0 ]]
        then
            bt_variable_clone build_settings BT_TARGET_OPTION_BUILD_SETTINGS
        fi

        if [[ ${#macros[@]} -gt 0 ]]
        then
            bt_variable_clone macros BT_TARGET_OPTION_MACROS
        fi

        if [[ -n "${out}" ]]
        then
            local -a arguments=("${@}")

            printf "%s=" "${out}"
            bt_variable_clone arguments
            printf "\n"
        fi

        local target_name_uppercase="`bt_string_uppercase <<< "${BT_TARGET_NAME}"`"
        for variable in ${!BT_TARGET_OPTION_@} `bt_variable_expand "${target_name_uppercase}"`
        do
            if ! bt_variable_is_readonly "${variable}"
            then
                bt_variable_print "${variable}"
            fi
        done

        return 0
    }

    eval "`bt_target_getopt_internal "${@}"`"
    unset bt_target_getopt_internal

    bt_log_variable ${!BT_TARGET_OPTION_@}
    bt_target_sanity_check

    DEVELOPER_DIR="`bt_xcode_get_path "${BT_TARGET_OPTION_XCODE}"`"
    export DEVELOPER_DIR
}

function bt_target_xcodebuild
{
    local compiler=""
    bt_variable_clone "BT_SDK_${BT_TARGET_OPTION_SDK//./_}_COMPILER" compiler

    local -a command=(/usr/bin/xcodebuild
                      -configuration "${BT_TARGET_OPTION_BUILD_CONFIGURATION}"
                      CONFIGURATION_BUILD_DIR="`bt_target_get_build_directory "${BT_TARGET_NAME}"`"
                      SDKROOT="macosx${BT_TARGET_OPTION_SDK}"
                      ARCHS="`bt_array_join BT_TARGET_OPTION_ARCHITECTURES " "`"
                      GCC_VERSION="${compiler}"
                      MACOSX_DEPLOYMENT_TARGET="${BT_TARGET_OPTION_DEPLOYMENT_TARGET}"
                      CODE_SIGN_IDENTITY="${BT_TARGET_OPTION_CODE_SIGN_IDENTITY}"
                      "${BT_TARGET_OPTION_BUILD_SETTINGS[@]}")
    if [[ ${#BT_TARGET_OPTION_MACROS} -gt 0 ]]
    then
        command+=(GCC_PREPROCESSOR_DEFINITIONS="\$(inherited)`printf " %q" "${BT_TARGET_OPTION_MACROS[@]}"`")
    fi
    command+=("${@}")

    "${command[@]}" 1>&3 2>&4
}

function bt_target_configure
{
    local sdk_path="`xcodebuild -version -sdk macosx${BT_TARGET_OPTION_SDK} Path`"
    if [[ "${sdk_path}" =~ [[:space:]] ]]
    then
        bt_error "OS X ${BT_TARGET_OPTION_SDK} SDK path '${sdk_path}' contains whitespace"
    fi

    local compiler=""
    bt_variable_clone "BT_SDK_${BT_TARGET_OPTION_SDK//./_}_COMPILER" compiler

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
            bt_error "Compiler '${compiler}' is not supported"
            ;;
    esac

    for macro in "${BT_TARGET_OPTION_MACROS[@]}"
    do
        bt_assert "[[ `bt_string_escape "${macro}"` =~ ^[^[:space:]]*$ ]]" "Macro '${macro//\'/\\\'}' contains whitespace"
    done

    MAKE="`/usr/bin/xcrun --find make`" \
    CPP="`/usr/bin/xcrun --find cpp`" \
    CC="`/usr/bin/xcrun --find "${compiler_binary}"`" \
    LD="`/usr/bin/xcrun --find ld`" \
    CPPFLAGS="-Wp,-isysroot,${sdk_path} ${CPPFLAGS}" \
    CFLAGS="${BT_TARGET_OPTION_ARCHITECTURES[@]/#/-arch } -isysroot ${sdk_path} -mmacosx-version-min=${BT_TARGET_OPTION_DEPLOYMENT_TARGET}${BT_TARGET_OPTION_MACROS[@]/#/ -D} ${CFLAGS}" \
    LDFLAGS="-Wl,-syslibroot,${sdk_path} -Wl,-macosx_version_min,${BT_TARGET_OPTION_DEPLOYMENT_TARGET} ${LDFLAGS}" \
    ./configure --prefix="${BT_TARGET_OPTION_PREFIX}" "${@}" 1>&3 2>&4
}

function bt_target_make
{
    local -a options=()
    bt_getopt options "root,no-root" "${@}"
    bt_exit_on_error "${options[@]}"

    set -- "${options[@]}"

    local -i root="${BT_TARGET_OPTION_ROOT}"

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
        bt_sudo "Enter password to run make" "${command[@]}" 1>&3 2>&4
    fi
}

function bt_target_codesign
{
    if [[ -n "${BT_TARGET_OPTION_CODE_SIGN_IDENTITY}" ]]
    then
        /usr/bin/xcrun codesign -s "${BT_TARGET_OPTION_CODE_SIGN_IDENTITY}" -f "${@}" 1>&3 2>&4
    else
        return 0
    fi
}

function bt_target_pkgbuild
{
    local command=(/usr/bin/pkgbuild)

    if [[ -n "${BT_TARGET_OPTION_PRODUCT_SIGN_IDENTITY}" ]]
    then
        command+=(--sign "${BT_TARGET_OPTION_PRODUCT_SIGN_IDENTITY}")
    fi

    command+=("${@}")

    "${command[@]}" 1>&3 2>&4
}

function bt_target_pkgbuild_component_plist_foreach
{
    bt_assert "bt_is_function `bt_string_escape "${3}"`"
    bt_assert "[[ ! `bt_string_escape "${3}"` =~ ^bt_pkgbuild_component_plist_foreach_ ]]"

    if [[ "`bt_plist_array_size "${1}" "${2}"`" -gt 0 ]]
    then
        eval "
            function bt_pkgbuild_component_plist_foreach_internal
            {
                while [[ \${#} -gt 0 ]]
                do
                    ${3} `bt_string_escape "${1}"` ${2}:\${1}

                    if /usr/libexec/PlistBuddy -c \"Print '${2}:\${1}:ChildBundles'\" `bt_string_escape "${1}"` > /dev/null 2>&1
                    then
                        bt_target_pkgbuild_component_plist_foreach `bt_string_escape "${1}"` \"${2}:\${1}:ChildBundles\" ${3}
                    fi
                    shift
                done
            }
        " && bt_pkgbuild_component_plist_foreach_internal $(/usr/bin/jot - 0 $(( $(bt_plist_array_size "${1}" "${2}") - 1 )))
    fi
}

function bt_target_productbuild
{
    local command=(/usr/bin/productbuild)

    if [[ -n "${BT_TARGET_OPTION_PRODUCT_SIGN_IDENTITY}" ]]
    then
        command+=(--sign "${BT_TARGET_OPTION_PRODUCT_SIGN_IDENTITY}")
    fi

    command+=("${@}")

    "${command[@]}" 1>&3 2>&4
}

function bt_target_install
{
    local -a options=()
    bt_getopt options "r,root,o:,owner:,g:,group:" "${@}"
    bt_exit_on_error "${options[@]}"

    set -- "${options[@]}"

    local -i root="${BT_TARGET_OPTION_ROOT}"
    local    owner="${BT_TARGET_OPTION_OWNER}"
    local    group="${BT_TARGET_OPTION_GROUP}"

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

    bt_assert "[[ -e `bt_string_escape "${source}"` ]]"
    bt_assert "[[ -d `bt_string_escape "${target_directory}"` ]]"

    local target="${target_directory}"
    if [[ ! "${source}" =~ /$ ]]
    then
        target="${target}/${source##*/}"
        bt_assert "[[ ! -e `bt_string_escape "${target}"` ]]" "Target is already installed"
    fi

    local -a command=(/bin/cp -a "${source}" "${target}")
    if (( root == 0 ))
    then
        "${command[@]}" 1>&3 2>&4
    else
        bt_sudo "Enter password to install target" "${command[@]}" 1>&3 2>&4
    fi
    bt_exit_on_error "Failed to install target"

    if [[ -n "${owner}" || -n "${group}" ]]
    then
        bt_sudo "Enter password to change owner and/or group of installed target" chown -R "${owner}:${group}" "${target}" 1>&3 2>&4
        bt_exit_on_error "Failed to change owner and/or group of installed target"
    fi
}

function bt_target_invoke
{
    local target_name="${1}"
    local action="${2}"

    local target_path="${BT_BUILD_D}/targets/${target_name}.sh"

    bt_assert "bt_function_is_legal_name `bt_string_escape "${target_name}"`"
    bt_assert "[[ -f `bt_string_escape "${target_path}"` ]]" "Target '${target_name}' does not exist"

    (
        eval "
            function ${target_name}_build
            {
                bt_error -t \"Action '\${BT_TARGET_ACTION}' of target '\${BT_TARGET_NAME}' needs to be overridden\"
            }

            function ${target_name}_clean
            {
                bt_target_getopt -p clean -- \"\${@}\"

                bt_log -v 3 \"Removing target build directory '\${BT_TARGET_BUILD_DIRECTORY}'\"

                if [[ -e \"\${BT_TARGET_BUILD_DIRECTORY}\" ]]
                then
                    local command=(rm -rf \"\${BT_TARGET_BUILD_DIRECTORY}\")
                    if (( BT_TARGET_OPTION_ROOT == 0 ))
                    then
                        \"\${command[@]}\" 1>&3 2>&4
                    else
                        bt_sudo \"Enter password to remove target build directory\" \"\${command[@]}\" 1>&3 2>&4
                    fi
                fi
            }

            function ${target_name}_help
            {
                bt_help

                printf \"Target:   %s\n\n\" \"\${BT_TARGET_NAME}\"

                printf \"Actions:\r\"
                for action in \"\${BT_TARGET_ACTIONS[@]}\"
                do
                    printf \"\033[10C%s\n\" \"\${action}\"
                done
            }
        "

        declare -r  BT_TARGET_NAME="${target_name}"
        declare -r  BT_TARGET_PATH="${target_path}"

        declare -r  BT_TARGET_ACTION="${action}"
        declare -ra BT_TARGET_ACTION_ARGUMENTS=("${@:3}")

        declare -a  BT_TARGET_ACTIONS=()
        declare     BT_TARGET_SOURCE_DIRECTORY="${BT_SOURCE_DIRECTORY}"
        declare     BT_TARGET_BUILD_DIRECTORY="`bt_target_get_build_directory "${BT_TARGET_NAME}"`"

        # Options

        declare     BT_TARGET_OPTION_SDK="${BT_DEFAULT_SDK}"
        declare     BT_TARGET_OPTION_XCODE=""
        declare -a  BT_TARGET_OPTION_ARCHITECTURES=()
        declare     BT_TARGET_OPTION_DEPLOYMENT_TARGET="${BT_DEFAULT_SDK}"
        declare     BT_TARGET_OPTION_BUILD_CONFIGURATION="${BT_DEFAULT_BUILD_CONFIGURATION}"
        declare -a  BT_TARGET_OPTION_BUILD_SETTINGS=()
        declare -a  BT_TARGET_OPTION_MACROS=()
        declare     BT_TARGET_OPTION_CODE_SIGN_IDENTITY=""
        declare     BT_TARGET_OPTION_PRODUCT_SIGN_IDENTITY=""
        declare     BT_TARGET_OPTION_PREFIX="${BT_DEFAULT_PREFIX}"
        declare -i  BT_TARGET_OPTION_ROOT=0
        declare     BT_TARGET_OPTION_OWNER=""
        declare     BT_TARGET_OPTION_GROUP=""
        declare     BT_TARGET_OPTION_DEBUG_DIRECTORY=""

        bt_array_get BT_SDK_${BT_TARGET_OPTION_SDK/./_}_XCODE 0 BT_TARGET_OPTION_XCODE
        bt_variable_clone BT_SDK_${BT_TARGET_OPTION_SDK/./_}_ARCHITECURES BT_TARGET_OPTION_ARCHITECTURES

        # Source target

        bt_stack_push BT_LOG_PREFIX "T:${BT_TARGET_NAME}"

        bt_log -v 3 "Source target ${BT_TARGET_NAME}"

        source "${target_path}" 1>&3 2>&4
        bt_exit_on_error "Failed to source target"

        bt_assert "bt_is_array BT_TARGET_ACTIONS"
        bt_assert "bt_array_contains BT_TARGET_ACTIONS `bt_string_escape "${BT_TARGET_ACTION}"`" \
                  "Unsupported target action: '${BT_TARGET_ACTION}'"

        declare DEVELOPER_DIR="`bt_xcode_get_path "${BT_TARGET_OPTION_XCODE}"`"
        export DEVELOPER_DIR

        # Invoke target action

        pushd "${BT_TARGET_SOURCE_DIRECTORY}" > /dev/null 2>&1
        bt_warn_on_error "Target source directory '${BT_TARGET_SOURCE_DIRECTORY}' does not exist"

        bt_log -v 3 "Invoke action ${BT_TARGET_ACTION}"

        "${target_name}_${BT_TARGET_ACTION}" "${BT_TARGET_ACTION_ARGUMENTS[@]}"
        declare -i rc=${?}

        bt_log -v 3 "Completed action ${BT_TARGET_ACTION}"

        popd > /dev/null 2>&1

        bt_stack_pop BT_LOG_PREFIX
        exit ${rc}
    )
}


function bt_clean
{
    bt_log -v 2 "Removing build directory '${BT_BUILD_DIRECTORY}'"
    if [[ -e "${BT_BUILD_DIRECTORY}" ]]
    then
        rm -rf "${BT_BUILD_DIRECTORY}"
    fi
}

function bt_help
{
    local script="${BASH_SOURCE[0]##*/}"

/bin/cat <<EOF
Copyright (c) 2011-2014 Benjamin Fleischer
All rights reserved.

Usage:     ${script} [options ...] (-h|--help)  [(-t|--target) {target name}]
           ${script} [options ...] (-c|--clean) [(-t|--target) {target name}]

           ${script} [options ...] (-t|--target) {target name} [(-a|--action) {action}] -- [action options ...]


Options:   [-v {verbose level}|--verbose={verbose level}]

Installed Xcode versions: `bt_array_join BT_XCODE_INSTALLED ", "`
Installed OS X SDKs:      `bt_array_join BT_SDK_INSTALLED ", "`
EOF
}

function bt_main
{
    bt_log_initialize

    declare -r BT_BUILD_D="$(bt_path_absolute "${BASH_SOURCE[0]%/*}/build.d")"

    # Source defaults

    local defaults_path="${BT_BUILD_D}/defaults.sh"

    bt_log -v 3 "Source defaults"

    bt_stack_push BT_LOG_PREFIX "Defaults"

    source "${defaults_path}" 1>&3 2>&4
    bt_exit_on_error "Failed to source defaults '${defaults_path}'"

    bt_variable_require BT_DEFAULT_SOURCE_DIRECTORY \
                        BT_DEFAULT_BUILD_DIRECTORY \
                        BT_DEFAULT_LOG_VERBOSE \
                        BT_SDK_SUPPORTED \
                        BT_DEFAULT_SDK \
                        BT_DEFAULT_BUILD_CONFIGURATION \
                        BT_DEFAULT_PREFIX

    bt_stack_pop BT_LOG_PREFIX

    # Initialize settings

    BT_SOURCE_DIRECTORY="${BT_DEFAULT_SOURCE_DIRECTORY}"
    BT_BUILD_DIRECTORY="${BT_DEFAULT_BUILD_DIRECTORY}"

    bt_log_set_verbose "${BT_DEFAULT_LOG_VERBOSE}"

    # Parse options

    local -a options=()
    bt_getopt options "h,help,c,clean,v:,verbose:,s:,source-directory:,b:,build-directory:,t:,target:,a:,action:" "${@}"
    bt_exit_on_error "${options[@]}"

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
                BT_SOURCE_DIRECTORY="`bt_path_absolute "${2}"`"
                shift 2
                ;;
            -b|--build-directory)
                BT_BUILD_DIRECTORY="`bt_path_absolute "${2}"`"
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

    if ! bt_math_is_integer "${verbose}" || [[ ${verbose} -lt 1 ]]
    then
        bt_error "Verbosity must be a positive integer"
    fi
    bt_log_set_verbose "${verbose}"

    # Find Xcode installations

    bt_xcode_find

    if [[ ${#BT_XCODE_INSTALLED[@]} -eq 0 ]]
    then
        bt_error "No version of Xcode found"
    fi
    if [[ ${#BT_SDK_INSTALLED} -eq 0 ]]
    then
        bt_error "No supported OS X SDK installed"
    fi

    # Check settings

    if [[ ! -e "${BT_SOURCE_DIRECTORY}" ]]
    then
        bt_warn "Source directory '${BT_SOURCE_DIRECTORY}' does not exist"
    fi

    if [[ -z "${BT_DEFAULT_SDK}" ]] || ! bt_sdk_is_installed "${BT_DEFAULT_SDK}"
    then
        if bt_variable_is_readonly BT_DEFAULT_SDK
        then
            bt_error "Default OS X SDK not available"
        else
            local osx_version="`bt_osx_get_version`"

            function bt_main_default_sdk
            {
                if [[ -z "${BT_DEFAULT_SDK}" ]]
                then
                    BT_DEFAULT_SDK="${1}"
                else
                    bt_version_compare "${1}" "${osx_version}"
                    if [[ ${?} -eq 2 ]]
                    then
                        return 1
                    else
                        BT_DEFAULT_SDK="${1}"
                    fi
                fi
            }

            BT_DEFAULT_SDK=""
            bt_array_foreach BT_SDK_INSTALLED bt_main_default_sdk

            unset bt_main_default_sdk

            bt_assert "[[ -n `bt_string_escape "${BT_DEFAULT_SDK}"` ]]"
            bt_warn "Falling back to OS X ${BT_DEFAULT_SDK} SDK as default SDK"
        fi
    fi

    local variable=""
    for variable in BT_SOURCE_DIRECTORY BT_BUILD_DIRECTORY ${!BT_DEFAULT_@}
    do
        readonly ${variable}
    done

    bt_log_variable BT_SOURCE_DIRECTORY \
                    BT_BUILD_DIRECTORY \
                    ${!BT_DEFAULT_@}

    # Source extensions

    local extension_path=""
    for extension_path in "${BT_BUILD_D}/extensions"/*.sh
    do
        local extension_basename="${extension_path##*/}"
        local extension_name="${extension_basename%.*}"

        bt_log -v 3 "Source extension ${extension_name}"

        bt_stack_push BT_LOG_PREFIX "E:${extension_name}"

        source "${extension_path}" 1>&3 2>&4
        bt_exit_on_error "Failed to source extension '${extension_path}'"

        bt_stack_pop BT_LOG_PREFIX
    done

    # Invoke target action

    pushd "${BT_SOURCE_DIRECTORY}" > /dev/null 2>&1
    bt_warn_on_error "Source directory '${BT_SOURCE_DIRECTORY}' does not exist"

    if (( help != 0 ))
    then
        if [[ -n "${target_name}" ]]
        then
            action="help"
        else
            bt_help
        fi
    elif (( clean != 0 ))
    then
        if [[ -n "${target_name}" ]]
        then
            action="clean"
        else
            bt_clean
        fi
    elif [[ -z "${target_name}" ]]
    then
        bt_error "No target specified"
    fi

    if [[ -n "${target_name}" ]]
    then
        bt_target_invoke "${target_name}" "${action}" "${@}"
        bt_exit_on_error "Action '${action}' of target '${target_name}' failed"
    fi

    popd > /dev/null 2>&1
    return 0
}


for signal in SIGINT SIGTERM
do
    trap "bt_signal_handler \"${signal}\"" "${signal}"
done

bt_main "${@}"
