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


function string_trim
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

function string_lowercase
{
    /usr/bin/tr '[A-Z]' '[a-z]'
}

function string_uppercase
{
    /usr/bin/tr '[a-z]' '[A-Z]'
}

function string_escape
{
    local count="${2:-1}"

    if [[ "${count}" =~ [0-9]+ ]] && (( count > 0 ))
    then
        printf "%q" "`string_escape "${1}" $(( count - 1 ))`"
    else
        printf "%s" "${1}"
    fi
}

function string_compare
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
