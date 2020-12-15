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


# Build tool defaults

declare -r  DEFAULT_SOURCE_DIRECTORY="$(common_path_absolute "$(dirname "${0}")")"
declare -r  DEFAULT_BUILD_DIRECTORY="/tmp/osxfuse"

declare -ri DEFAULT_LOG_VERBOSE=2


# Xcode defaults

declare -ra DEFAULT_SDK_10_5_ARCHITECURES=("ppc" "ppc64" "i386" "x86_64")
declare -r  DEFAULT_SDK_10_5_COMPILER="4.2"

declare -ra DEFAULT_SDK_10_6_ARCHITECURES=("i386" "x86_64")
declare -r  DEFAULT_SDK_10_6_COMPILER="com.apple.compilers.llvmgcc42"

declare -ra DEFAULT_SDK_10_7_ARCHITECURES=("i386" "x86_64")
declare -r  DEFAULT_SDK_10_7_COMPILER="com.apple.compilers.llvmgcc42"

declare -ra DEFAULT_SDK_10_8_ARCHITECURES=("i386" "x86_64")
declare -r  DEFAULT_SDK_10_8_COMPILER="com.apple.compilers.llvm.clang.1_0"

declare -ra DEFAULT_SDK_10_9_ARCHITECURES=("i386" "x86_64")
declare -r  DEFAULT_SDK_10_9_COMPILER="com.apple.compilers.llvm.clang.1_0"

declare -ra DEFAULT_SDK_10_10_ARCHITECURES=("i386" "x86_64")
declare -r  DEFAULT_SDK_10_10_COMPILER="com.apple.compilers.llvm.clang.1_0"

declare -ra DEFAULT_SDK_10_11_ARCHITECURES=("i386" "x86_64")
declare -r  DEFAULT_SDK_10_11_COMPILER="com.apple.compilers.llvm.clang.1_0"

declare -ra DEFAULT_SDK_10_12_ARCHITECURES=("i386" "x86_64")
declare -r  DEFAULT_SDK_10_12_COMPILER="com.apple.compilers.llvm.clang.1_0"

declare -ra DEFAULT_SDK_10_13_ARCHITECURES=("i386" "x86_64")
declare -r  DEFAULT_SDK_10_13_COMPILER="com.apple.compilers.llvm.clang.1_0"

declare -ra DEFAULT_SDK_10_14_ARCHITECURES=("x86_64")
declare -r  DEFAULT_SDK_10_14_COMPILER="com.apple.compilers.llvm.clang.1_0"

declare -ra DEFAULT_SDK_10_15_ARCHITECURES=("x86_64")
declare -r  DEFAULT_SDK_10_15_COMPILER="com.apple.compilers.llvm.clang.1_0"

declare -ra DEFAULT_SDK_SUPPORTED=("10.5" "10.6" "10.7" "10.8" "10.9" "10.10" "10.11" "10.12" "10.13" "10.14" "10.15")

declare     DEFAULT_SDK="`macos_get_version`"
declare -r  DEFAULT_BUILD_CONFIGURATION="Release"


# Autotools defaults

declare -r  DEFAULT_PREFIX=""
