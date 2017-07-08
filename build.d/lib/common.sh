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
# 3. Neither the name of the copyright holder nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
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

# Requires array.sh
# Requires math.sh
# Requires string.sh


declare -a COMMON_LOG_PREFIX=()
declare -i COMMON_LOG_VERBOSE=2


function common_log_initialize
{
    common_log_set_verbose ${COMMON_LOG_VERBOSE}
}

function common_log_set_verbose
{
    local verbose="${1}"

    common_assert "math_is_integer `string_escape "${verbose}"`"
    common_assert "[[ ${verbose} -gt 0 ]]"

    COMMON_LOG_VERBOSE=${verbose}

    if (( COMMON_LOG_VERBOSE > 4 ))
    then
        exec 3>&1
        exec 4>&2
    else
        exec 3> /dev/null
        exec 4> /dev/null
    fi
}

function common_log
{
    local -a options=()
    common_getopt options "v:,verbose:,c:,color:,t,trace,o:,offset:" "${@}"
    common_die_on_error "${options[@]}"

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

    if (( verbose > COMMON_LOG_VERBOSE ))
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

            array_append stack "at ${function} (${file}, line ${line})"

            (( i++ ))
        done

        set -- "${@}" "${stack[@]}"
    fi

    while [[ ${#} -gt 0 ]]
    do
        if [[ ${#COMMON_LOG_PREFIX[@]} -gt 0 ]]
        then
            printf "%-20s | " "${COMMON_LOG_PREFIX}" >&2
        fi
        printf "\033[${color}m%s\033[0m\n" "${1}" >&2
        shift
    done
}

function common_log_variable
{
    while [[ ${#} -gt 0 ]]
    do
        common_log -v 4 -- "`common_variable_print "${1}"`"
        shift
    done
}

function common_warn
{
    common_log -v 1 -c "0;31" -o 1 "${@}"
}

function common_die
{
    if [[ ${#} -eq 0 ]]
    then
        set -- "Unspecified error"
    fi

    common_log -v 1 -c "1;31" -o 1 "${@}"
    echo -ne "\a" >&2

    if (( BASH_SUBSHELL > 0 ))
    then
        kill -SIGTERM 0
    fi
    exit 1
}

function common_assert
{
    if [[ -n "${1}" ]]
    then
        eval "${1}"
        if (( ${?} != 0 ))
        then
            if [[ -n "${2}" ]]
            then
                common_die -t -o 2 "${2}"
            else
                common_die -t -o 2 "Assertion '${1}' failed"
            fi
        fi
    fi
}

function common_die_on_error
{
    if (( ${?} != 0 ))
    then
        common_die "${@}"
    fi
}

function common_warn_on_error
{
    if (( ${?} != 0 ))
    then
        common_warn "${@}"
    fi
}


function common_signal_trap_initialize
{
    local signal=""
    for signal in SIGINT SIGTERM
    do
        trap "common_signal_trap \"${signal}\"" "${signal}"
    done
}

function common_signal_trap
{
    local signal="${1}"

    common_log -v 4 "Received signal: ${signal}"
    case "${signal}" in
        SIGINT)
            common_warn "Aborted by user"
            exit 130
            ;;
        SIGTERM)
            exit 143
            ;;
        *)
            common_warn "Ignore signal: ${signal}"
            ;;
    esac
}


function common_getopt
{
	function common_getopt_internal
	{
        local variable="${1}"

        local -a specs=()
        IFS="," read -ra specs <<< "${2}"

        common_assert "array_is_array `string_escape ${variable}`"

        local -i error=0
        local -a out=()

        function common_getopt_spec
	    {
	        case "${1: -1}" in
	            ":")
	                common_variable_set "${2}" "${1:0:$((${#1} - 1))}"
	                common_variable_set "${3}" 1
	                ;;
	            "?")
	                common_variable_set "${2}" "${1:0:$((${#1} - 1))}"
	                common_variable_set "${3}" 2
	                ;;
	            *)
	                common_variable_set "${2}" "${1}"
	                common_variable_set "${3}" 0
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
		                common_getopt_spec "${spec}" spec_name spec_has_argument

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
		                common_getopt_spec "${spec}" spec_name spec_has_argument

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

        printf "%s=%s\n" "${variable}" "`common_variable_clone out`"
        printf "return %d\n" ${error}
	}

    eval "`common_getopt_internal "${@}"`"
}

function common_sudo
{
    local prompt="${1}"

    common_assert "[[ -n `string_escape "${prompt}"` ]]"
    common_assert "[[ ${#} -gt 1 ]]"

    if [[ ${#COMMON_LOG_PREFIX[@]} -gt 0 ]]
    then
        prompt="`printf "%-20s | %s" "${COMMON_LOG_PREFIX}" "${prompt}"`"
    fi

    sudo -p "${prompt}: " "${@:2}"
}


function common_is_function
{
    [[ "`type -t "${1}"`" == "function" ]]
}

function common_function_is_legal_name
{
    [[ "${1}" =~ ^[a-zA-Z_][0-9a-zA-Z_]*$ ]]
}


function common_is_variable
{
    compgen -A variable | grep ^"${1}"$ > /dev/null
}

function common_variable_is_legal_name
{
    [[ "${1}" =~ ^[a-zA-Z_][0-9a-zA-Z_]*$ ]]
}

function common_variable_is_readonly
{
    if common_is_variable "${1}"
    then
        [[ "`declare -p "${1}" 2> /dev/null`" =~ ^"declare -"[^=]{0,}"r"[^=]{0,}" ${1}=" ]]
    fi
}

function common_variable_get
{
    common_assert "common_is_variable `string_escape "${1}"`"

    string_escape "${!1}"
}

function common_variable_set
{
    common_assert "common_variable_is_legal_name `string_escape "${1}"`"

    eval "${1}=`string_escape "${2}"`"
}

function common_variable_clone
{
    if [[ -z "${2}" ]]
    then
        common_assert "common_is_variable `string_escape "${1}"`"

        if array_is_array "${1}"
        then
            printf "("
            array_get_elements "${1}"
            printf ")"
        else
            common_variable_get "${1}"
        fi
    else
        common_assert "common_variable_is_legal_name `string_escape "${2}"`"

        eval "${2}=`common_variable_clone "${1}"`"
    fi
}

function common_variable_print
{
    common_assert "common_is_variable `string_escape "${1}"`"

    printf "%s=" "${1}"
    common_variable_clone "${1}"
    printf "\n"
}

function common_variable_require
{
    while [[ ${#} -gt 0 ]]
    do
        if ! common_is_variable "${1}"
        then
            common_die "Variable not declared: ${1}"
        fi
        shift
    done
}

function common_variable_expand
{
    while [[ ${#} -gt 0 ]]
    do
        eval "echo \${!${1}@}"
        shift
    done
}


function common_path_absolute
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
    array_join tokens "/"
}
