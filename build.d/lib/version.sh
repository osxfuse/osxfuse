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


function version_is_version
{
    [[ "${1}" =~ ^[0-9]+(\.[0-9]+)*$ ]]
}

function version_compare
{
    common_assert "version_is_version `string_escape "${1}"`"
    common_assert "version_is_version `string_escape "${2}"`"

    local -a version1=()
    local -a version2=()

    IFS="." read -ra version1 <<< "${1}"
    IFS="." read -ra version2 <<< "${2}"

    local -i i=0
    local    t1=""
    local    t2=""
    for (( i=0 ; i < `math_max ${#version1[@]} ${#version2[@]}` ; i++ ))
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

function version_compare_eq
{
    version_compare "${1}" "${2}"
    (( ${?} == 0 ))
}

function version_compare_le
{
    version_compare "${1}" "${2}"
    (( ${?} != 2 ))
}

function version_compare_ge
{
    version_compare "${1}" "${2}"
    (( ${?} != 1 ))
}
