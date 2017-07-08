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

# Requires common.sh
# Requires math.sh
# Requires string.sh


function array_is_array
{
    if common_is_variable "${1}"
    then
        [[ "`declare -p "${1}" 2> /dev/null`" =~ ^"declare -"[^=]{0,}"a"[^=]{0,}" ${1}=" ]]
    else
        return 1
    fi
}

function array_create
{
    common_assert "common_variable_is_legal_name `string_escape "${1}"`"

    eval "${1}=()"
}

function array_size
{
    common_assert "array_is_array `string_escape "${1}"`"

    eval "printf \"%u\" \${#${1}[@]}"
}

function array_get
{
    if [[ -z "${3}" ]]
    then
        common_assert "common_is_variable `string_escape "${1}"`"
        common_assert "math_is_integer `string_escape "${2}"` && [[ ${2} -ge 0 ]]"

        eval "string_escape \"\${${1}[${2}]}\""
    else
        common_assert "common_is_variable `string_escape "${3}"`"

        eval "${3}=`array_get "${1}" "${2}"`"
    fi
}

function array_set
{
    common_assert "common_is_variable `string_escape "${1}"`"
    common_assert "math_is_integer `string_escape "${2}"` && [[ ${2} -ge 0 ]]"

    eval "${1}[${2}]=`string_escape "${3}"`"
}

function array_append
{
    common_assert "common_is_variable `string_escape "${1}"`"

    eval "${1}+=(`string_escape "${2}"`)"
}

function array_get_elements
{
    common_assert "common_is_variable `string_escape "${1}"`"

    function array_get_elements_serialize
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
    eval "array_get_elements_serialize \"\${!${1}[@]}\" \"\${${1}[@]}\""

    local rc=${?}
    unset -f array_get_elements_serialize
    return ${rc}
}

function array_foreach
{
    common_assert "common_is_variable `string_escape "${1}"`"
    common_assert "common_is_function `string_escape "${2}"`"
    common_assert "[[ ! `string_escape "${2}"` =~ ^array_foreach_ ]]"

    eval "
        function array_foreach_internal
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

        function array_foreach_wrapper
        {
            array_foreach_internal \"\${${1}[@]}\"
        }
    " && array_foreach_wrapper

    local rc=${?}
    unset -f array_foreach_internal
    unset -f array_foreach_wrapper
    return ${rc}
}

function array_contains
{
    eval "
        function array_contains_compare
        {
            [[ \"\${1}\" != `string_escape "${2}"` ]]
        }
    " && ! array_foreach "${1}" array_contains_compare

    local rc=${?}
    unset -f array_contains_compare
    return ${rc}
}

function array_sort
{
    common_assert "common_is_variable `string_escape "${1}"`"
    common_assert "common_is_function `string_escape "${2}"`"
    common_assert "[[ ! `string_escape "${2}"` =~ ^array_sort_ ]]"
    common_assert "[[ `string_escape "${3}"` =~ !? ]]"

    eval "
        function array_sort_quicksort
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
                array_sort_quicksort \"\${left[@]}\"
            fi
            string_escape \"\${pivot}\"
            printf \"%s\" \"\${IFS}\"
            if [[ \${#right[@]} -gt 0 ]]
            then
                array_sort_quicksort \"\${right[@]}\"
            fi
        }

        function array_sort_wrapper
        {
            eval \"${1}=(\$(array_sort_quicksort \"\${${1}[@]}\"))\"
        }
    " && array_sort_wrapper

    local rc=${?}
    unset -f array_sort_quicksort
    unset -f array_sort_wrapper
    return ${rc}
}

function array_join
{
    common_assert "common_is_variable `string_escape "${1}"`"

    eval "
        function array_join_internal
        {
            printf \"%s\" \"\${1}\"
            shift
            while [[ \${#} -gt 0 ]]
            do
                printf \"%s%s\" `string_escape "${2:-, }"` \"\${1}\"
                shift
            done
            printf \"\n\"
        }

        function array_join_wrapper
        {
            array_join_internal \"\${${1}[@]}\"
        }
    " && array_join_wrapper

    local rc=${?}
    unset -f array_join_internal
    unset -f array_join_wrapper
    return ${rc}
}
