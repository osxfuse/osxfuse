#!/bin/bash

# OSXFUSE build tool

# Copyright (c) 2008-2009 Google Inc.
# Copyright (c) 2011-2012 Benjamin Fleischer
# All rights reserved.

# Configurables
#
# Beware: GNU libtool cannot handle directory names containing whitespace.
#         Therefore, do not set M_CONF_TMPDIR to such a directory.
#
readonly M_CONF_TMPDIR=/tmp
readonly M_PLISTSIGNER_TEST_KEY="`dirname $0`/prefpane/autoinstaller/TestKeys/private_key.der"

# Other constants
#
readonly M_PROGDESC="OSXFUSE build tool"
readonly M_PROGNAME=`basename $0`
readonly M_PROGVERS=2.0

readonly M_DEFAULT_VALUE=__default__

readonly M_CONFIGURATIONS="Debug Release" # default is Release

readonly M_TARGETS="clean release dist core osxfusefs kext examples lib reload"
readonly M_TARGETS_WITH_PLATFORM="kext examples lib"

readonly M_DEFAULT_PLATFORM="$M_DEFAULT_VALUE"
readonly M_DEFAULT_TARGET="$M_DEFAULT_VALUE"

# Globals
#
declare m_args=
declare m_active_target=""
declare m_configuration="Release"
declare m_developer=0
declare m_osname=""
declare m_platform="$M_DEFAULT_PLATFORM"
declare m_archs=""
declare m_release=""
declare m_shortcircuit=0
declare m_srcroot=""
declare m_stderr=/dev/stderr
declare m_stdout=/dev/stdout
declare m_suprompt=" invalid "
declare m_target="$M_DEFAULT_TARGET"
declare m_signing_id=""
declare m_plistsigner_key=""
declare m_usdk_dir=""
declare m_compiler=""
declare m_xcode_dir=""
declare m_xcode_version=""
declare m_xcode_latest=""

declare mp_package_maker=""
declare mp_package_maker_version=""

# Other implementation details
#
declare M_XCODE32=""
declare M_XCODE32_VERSION=3.2
readonly M_XCODE32_COMPILER="4.2"
declare M_XCODE40=""
declare M_XCODE40_VERSION=4.0
readonly M_XCODE40_COMPILER="4.2"
declare M_XCODE41=""
declare M_XCODE41_VERSION=4.1
readonly M_XCODE41_COMPILER="4.2"
declare M_XCODE42=""
declare M_XCODE42_VERSION=4.2
readonly M_XCODE42_COMPILER="com.apple.compilers.llvmgcc42"
declare M_XCODE43=""
declare M_XCODE43_VERSION=4.3
readonly M_XCODE43_COMPILER="com.apple.compilers.llvmgcc42"
declare M_XCODE44=""
declare M_XCODE44_VERSION=4.4
readonly M_XCODE44_COMPILER="com.apple.compilers.llvmgcc42"
declare M_XCODE45=""
declare M_XCODE45_VERSION=4.5
readonly M_XCODE45_COMPILER="com.apple.compilers.llvmgcc42"

declare M_ACTUAL_PLATFORM=""
declare M_PLATFORMS=""
declare M_PLATFORMS_REALISTIC=""

declare M_XCODE_VERSION_REQUIRED=""

# SDK 10.5
readonly M_SDK_105_ARCHS="ppc ppc64 i386 x86_64"
declare M_SDK_105=""
declare M_SDK_105_XCODE=""
declare M_SDK_105_COMPILER=""

# SDK 10.6
readonly M_SDK_106_ARCHS="i386 x86_64"
declare M_SDK_106=""
declare M_SDK_106_XCODE=""
declare M_SDK_106_COMPILER=""

# SDK 10.7
readonly M_SDK_107_ARCHS="i386 x86_64"
declare M_SDK_107=""
declare M_SDK_107_XCODE=""
declare M_SDK_107_COMPILER=""

# SDK 10.8
readonly M_SDK_108_ARCHS="i386 x86_64"
declare M_SDK_108=""
declare M_SDK_108_XCODE=""
declare M_SDK_108_COMPILER=""

declare M_FSBUNDLE_NAME="osxfuse.fs"
declare M_KEXT_ID="com.github.osxfuse.filesystems.osxfusefs"
declare M_KEXT_NAME="osxfuse.kext"
readonly M_LOGPREFIX="OSXFUSEBuildTool"
readonly M_OSXFUSE_PRODUCT_ID="com.github.osxfuse.OSXFUSE"

readonly M_MACFUSE_MODE=0;

readonly M_PKG_VERSION="10.5"

# Core
readonly M_PKGID_CORE="com.github.osxfuse.pkg.Core"
readonly M_PKGBASENAME_CORE="OSXFUSECore"
readonly M_PKGNAME_CORE="${M_PKGBASENAME_CORE}.pkg"

# Preference Pane
readonly M_PKGID_PREFPANE="com.github.osxfuse.pkg.PrefPane"
readonly M_PKGBASENAME_PREFPANE="OSXFUSEPrefPane"
readonly M_PKGNAME_PREFPANE="${M_PKGBASENAME_PREFPANE}.pkg"

# MacFUSE compatibility layer
readonly M_PKGID_MACFUSE="com.google.macfuse.core"
readonly M_PKGBASENAME_MACFUSE="OSXFUSEMacFUSE"
readonly M_PKGNAME_MACFUSE="${M_PKGBASENAME_MACFUSE}.pkg"

# Distribution package
readonly M_PKGBASENAME_OSXFUSE="OSXFUSE"
readonly M_PKGNAME_OSXFUSE="${M_PKGBASENAME_OSXFUSE}.pkg"

# Redistribution package
readonly M_PKGID_REDIST="com.github.osxfuse.pkg.osxfuse"
readonly M_PKGBASENAME_REDIST="OSXFUSERedist"
readonly M_PKGNAME_REDIST="${M_PKGBASENAME_REDIST}.pkg"

readonly M_WANTSU="needs the Administrator password"
readonly M_WARNING="*** Warning"

function m_help()
{
    cat <<__END_HELP_CONTENT
$M_PROGDESC version $M_PROGVERS

Copyright (C) 2008 Google Inc.
Copyright (C) 2011-2012 Benjamin Fleischer
All Rights Reserved.

Usage:
  $M_PROGNAME
      [-dhqsv] [-c configuration] [-p platform] [-i identity] [-u keyfile]
      -t target

  * configuration is one of: $M_CONFIGURATIONS (default is $m_configuration)
  * platform is one of: $M_PLATFORMS (default is the host's platform)
  * target is one of: $M_TARGETS
  * platforms can only be specified for: $M_TARGETS_WITH_PLATFORM
  * identity and keyfile are ignored for all targets but release

The target keywords mean the following:
    clean       clean all targets
    release     create release disk image and updater files
    dist        create a multi-platform distribution package
    core        create a multi-platform core package
    osxfusefs   build file system bundle
    kext        build kernel extension
    examples    build example file systems (e.g. fusexmp_fh and hello)
    lib         build the user-space library (e.g. to run fusexmp_fh)
    reload      rebuild and reload the kernel extension

Options for target release are:

    -i identity
        sign the installer package with the specified signing identity
    -u keyfile
        sign the update rules file with the specified private key

Other options are:
    -d  create a developer prerelease package instead of a regular release
    -q  enable quiet mode (suppresses verbose build output)
    -s  enable shortcircuit mode (useful for testing the build mechanism itself)
    -v  report version numbers and quit
__END_HELP_CONTENT

    return 0
}

# m_version()
#
function m_version
{
    echo "$M_PROGDESC version $M_PROGVERS"

    m_set_platform
    m_set_srcroot

    local mv_release=`awk '/#define[ \t]*OSXFUSE_VERSION_LITERAL/ {print $NF}' "$m_srcroot/common/fuse_version.h"`
    if [ ! -z "$mv_release" ]
    then
        echo "OSXFUSE version $mv_release"
    fi

    return 0
}

# m_log(msg)
#
function m_log()
{
    printf "%-30s: %s\n" "$M_LOGPREFIX($m_active_target)" "$*"
}

# m_warn(msg)
#
function m_warn()
{
    echo "$M_WARNING: $*"
}

# m_exit_on_error(errmsg)
#
function m_exit_on_error()
{
    if [ "$?" != 0 ]
    then
        local retval=$?
        echo "$M_LOGPREFIX($m_active_target) failed: $1" 1>&2
        exit $retval
    fi

    # NOTREACHED
}

# m_set_suprompt(msg)
#
function m_set_suprompt()
{
    m_suprompt="$M_LOGPREFIX($m_active_target) $M_WANTSU $*: "
}

# m_set_srcroot()
#
function m_set_srcroot()
{
    local osxfuse_dir=""
    local is_absolute_path=`echo "$0" | cut -c1`
    if [ "$is_absolute_path" == "/" ]
    then
        osxfuse_dir="`dirname $0`/"
    else
        osxfuse_dir="`pwd`/`dirname $0`/"
    fi
    pushd . > /dev/null
    cd "$osxfuse_dir" || exit 1
    osxfuse_dir=`pwd`
    popd > /dev/null

    m_srcroot="$osxfuse_dir"
    return 0
}

# m_set_platform()
#
function m_set_platform()
{
    local retval=0

    if [ "$m_platform" == "$M_DEFAULT_PLATFORM" ]
    then
       m_platform=$M_ACTUAL_PLATFORM
    fi

    case "$m_platform" in
    10.5*)
        m_osname="Leopard"
        m_xcode_dir="$M_SDK_105_XCODE"
        m_usdk_dir="$M_SDK_105"
        m_compiler="$M_SDK_105_COMPILER"
        m_archs="$M_SDK_105_ARCHS"
    ;;
    10.6*)
        m_osname="Snow Leopard"
        m_xcode_dir="$M_SDK_106_XCODE"
        m_usdk_dir="$M_SDK_106"
        m_compiler="$M_SDK_106_COMPILER"
        m_archs="$M_SDK_106_ARCHS"
    ;;
    10.7*)
        m_osname="Lion"
        m_xcode_dir="$M_SDK_107_XCODE"
        m_usdk_dir="$M_SDK_107"
        m_compiler="$M_SDK_107_COMPILER"
        m_archs="$M_SDK_107_ARCHS"
    ;;
    10.8*)
        m_osname="Mountain Lion"
        m_xcode_dir="$M_SDK_108_XCODE"
        m_usdk_dir="$M_SDK_108"
        m_compiler="$M_SDK_108_COMPILER"
        m_archs="$M_SDK_108_ARCHS"
    ;;
    *)
        m_osname="Unknown"
        m_xcode_dir=""
        m_usdk_dir=""
        m_compiler=""
        m_archs=""
        retval=1
    ;;
    esac

    export DEVELOPER_DIR="$m_xcode_dir"

    return $retval
}

# m_build_pkg(pkgversion, install_srcroot, install_payload, pkgid, pkgname, install_to, output_dir)
#
function m_build_pkg()
{
    local bp_pkgversion="$1"
    local bp_install_srcroot="$2"
    local bp_install_payload="$3"
    local bp_pkgid="$4"
    local bp_pkgname="$5"
    local bp_install_to="$6"
    local bp_output_dir="$7"

    if [ -z "$mp_package_maker" ]
    then
        # Find PackageMaker.app
        local _IFS="$IFS"; IFS=$'\n'
        m_package_maker_installed=(`mdfind 'kMDItemCFBundleIdentifier == "com.apple.PackageMaker"'`)
        IFS="$_IFS"
        if [[ ${#m_package_maker_installed[@]} -eq 0 ]]
        then
            false
            m_exit_on_error "PackageMaker.app not found"
        fi

        # Use most recent version of PackageMaker.app
        for m_pm in "${m_package_maker_installed[@]}";
        do
            m_pm_version=`mdls -name kMDItemVersion "$m_pm" | perl -ne '/kMDItemVersion = "(.*)"/ && print $1'`
            m_version_compare "$mp_package_maker_version" "$m_pm_version"
            if [[ $? -ne 2 ]]
            then
                mp_package_maker="$m_pm"
                mp_package_maker_version="$m_pm_version"
            fi
        done
        m_log "package maker: $mp_package_maker (version $mp_package_maker_version)"
        mp_package_maker="$mp_package_maker/Contents/MacOS/PackageMaker"
    fi

    # Make the package
    m_set_suprompt "to run packagemaker"
    if [ -d "$bp_install_srcroot/Scripts" ]
    then
        sudo -p "$m_suprompt" \
            "$mp_package_maker" -r "$bp_install_payload" \
            -i "$bp_pkgid" \
            -f "$bp_install_srcroot/PackageInfo" \
            -o "$bp_output_dir/$bp_pkgname" \
            -n "$bp_pkgversion" \
            -l "$bp_install_to" \
            -s "$bp_install_srcroot/Scripts" \
            -g "$M_PKG_VERSION" \
            -h system \
            -m -w -v \
            >$m_stdout 2>$m_stderr
    else
        sudo -p "$m_suprompt" \
            "$mp_package_maker" -r "$bp_install_payload" \
            -i "$bp_pkgid" \
            -f "$bp_install_srcroot/PackageInfo" \
            -o "$bp_output_dir/$bp_pkgname" \
            -n "$bp_pkgversion" \
            -l "$bp_install_to" \
            -g "$M_PKG_VERSION" \
            -h system \
            -m -w -v \
            >$m_stdout 2>$m_stderr
    fi
    m_exit_on_error "cannot create package '$bp_pkgname'."

    return 0
}

# Build the user-space library
#
function m_handler_lib()
{
    m_active_target="lib"

    m_set_platform

    local lib_dir="$m_srcroot"/fuse
    if [ ! -d "$lib_dir" ]
    then
        false
        m_exit_on_error "cannot access directory '$lib_dir'."
    fi

    local kernel_dir="$m_srcroot"/kext
    if [ ! -d "$kernel_dir" ]
    then
        false
        m_exit_on_error "cannot access directory '$kernel_dir'."
    fi

    local package_name="fuse"

    rm -rf "$M_CONF_TMPDIR/$package_name"

    if [ "$1" == "clean" ]
    then
        local retval=$?
        m_log "cleaned (platform $m_platform)"
        return $retval
    fi

    m_log "initiating Universal build for $m_platform"

    cp -pRX "$lib_dir" "$M_CONF_TMPDIR"
    m_exit_on_error "cannot copy OSXFUSE library source from '$lib_dir'."

    cd "$M_CONF_TMPDIR/$package_name"
    m_exit_on_error "cannot access OSXFUSE library source in '$M_CONF_TMPDIR/$package_name'."

    m_log "configuring library source"
    COMPILER="$m_compiler" ARCHS="$m_archs" SDKROOT="$m_usdk_dir" MACOSX_DEPLOYMENT_TARGET="$m_platform" ./darwin_configure.sh "$m_srcroot" >$m_stdout 2>$m_stderr
    m_exit_on_error "cannot configure OSXFUSE library source for compilation."

    m_log "running make"
    xcrun make -j4 >$m_stdout 2>$m_stderr
    m_exit_on_error "make failed while compiling the OSXFUSE library."

    echo >$m_stdout
    m_log "succeeded, results in '$M_CONF_TMPDIR/$package_name'."
    echo >$m_stdout

    return 0
}

# Rebuild and reload the kernel extension
#
function m_handler_reload()
{
    m_active_target="reload"

    # Argument validation would have ensured that we use native platform
    # for this target.

    m_set_platform

    local kernel_dir="$m_srcroot"/kext
    if [ ! -d "$kernel_dir" ]
    then
        false
        m_exit_on_error "cannot access directory '$kernel_dir'."
    fi

    local ms_os_version="$m_platform"
    local ms_osxfuse_version=`awk '/#define[ \t]*OSXFUSE_VERSION_LITERAL/ {print $NF}' "$m_srcroot"/common/fuse_version.h`
    m_exit_on_error "cannot get platform-specific OSXFUSE version."

    local ms_osxfuse_out="$M_CONF_TMPDIR/osxfuse-kext-$ms_os_version-$ms_osxfuse_version"

    m_log "initiating kernel extension rebuild/reload for $m_platform"

    kextstat -l -b "$M_KEXT_ID" | grep "$M_KEXT_ID" >/dev/null 2>/dev/null
    if [ "$?" == "0" ]
    then
        m_log "unloading kernel extension"
        m_set_suprompt "to unload OSXFUSE kext"
        sudo -p "$m_suprompt" \
            kextunload -v -b "$M_KEXT_ID" >$m_stdout 2>$m_stderr
        m_exit_on_error "cannot unload kext '$M_KEXT_ID'."
    fi

    m_log "rebuilding kext"

    m_shortcircuit="0"
    m_configuration="Debug"
    m_handler_kext "$1"
    m_exit_on_error "failed to build kernel extension."

    m_active_target="reload"
    m_log "reloading kext"

    m_set_suprompt "to load newly built kernel extension"
    sudo -p "$m_suprompt" \
        kextutil -s "$ms_osxfuse_out" \
            -v "$ms_osxfuse_out/$M_KEXT_NAME" >$m_stdout 2>$m_stderr
    m_exit_on_error "cannot load newly built kernel extension."

    echo >$m_stdout
    m_log "checking status of kernel extension"
    kextstat -l -b "$M_KEXT_ID"
    echo >$m_stdout

    echo >$m_stdout
    m_log "succeeded, results in '$ms_osxfuse_out'."
    echo >$m_stdout

    return 0
}

# Build examples from the user-space OSXFUSE library
#
function m_handler_examples()
{
    m_active_target="examples"

    m_set_platform

    local lib_dir="$m_srcroot"/fuse
    if [ ! -d "$lib_dir" ]
    then
        false
        m_exit_on_error "cannot access directory '$lib_dir'."
    fi

    local kernel_dir="$m_srcroot"/kext
    if [ ! -d "$kernel_dir" ]
    then
        false
        m_exit_on_error "cannot access directory '$kernel_dir'."
    fi

    local package_name="fuse"

    rm -rf "$M_CONF_TMPDIR/$package_name"

    if [ "$1" == "clean" ]
    then
        local retval=$?
        m_log "cleaned (platform $m_platform)"
        return $retval
    fi

    m_log "initiating Universal build for $m_platform"

    cp -pRX "$lib_dir" "$M_CONF_TMPDIR"
    m_exit_on_error "cannot copy OSXFUSE library source from '$lib_dir'."

    cd "$M_CONF_TMPDIR/$package_name"
    m_exit_on_error "cannot access OSXFUSE library source in '$M_CONF_TMPDIR/$package_name'."

    m_log "configuring library source"
    COMPILER="$m_compiler" ARCHS="$m_archs" SDKROOT="$m_usdk_dir" MACOSX_DEPLOYMENT_TARGET="$m_platform" ./darwin_configure.sh "$m_srcroot" >$m_stdout 2>$m_stderr
    m_exit_on_error "cannot configure OSXFUSE library source for compilation."

    cd example
    m_exit_on_error "cannot access examples source."

    local me_installed_lib="/usr/local/lib/libosxfuse.la"

    perl -pi -e "s#../lib/libosxfuse.la#$me_installed_lib#g" Makefile
    m_exit_on_error "failed to prepare example source for build."

    m_log "running make"
    xcrun make -j4 >$m_stdout 2>$m_stderr
    m_exit_on_error "make failed while compiling the OSXFUSE examples."

    echo >$m_stdout
    m_log "succeeded, results in '$M_CONF_TMPDIR/$package_name/example'."
    echo >$m_stdout

    return 0
}

# Build a multiplatform distribution package
#
function m_handler_dist()
{
    m_active_target="dist"

    m_platform="${M_PLATFORMS_REALISTIC%% *}"
    m_set_platform

    m_release_full=`awk '/#define[ \t]*OSXFUSE_VERSION_LITERAL/ {print $NF}' "$m_srcroot/common/fuse_version.h"`
    m_release=`echo "$m_release_full" | cut -d . -f 1,2`
    m_exit_on_error "cannot get OSXFUSE release version."

    local md_osxfuse_out="$M_CONF_TMPDIR/osxfuse-dist-$m_release_full"
    local md_osxfuse_root="$md_osxfuse_out/pkgroot/"

    if [ "$m_shortcircuit" != "1" ]
    then
        if [ -e "$md_osxfuse_out" ]
        then
            m_set_suprompt "to remove a previously built distribution package"
            sudo -p "$m_suprompt" rm -rf "$md_osxfuse_out"
            m_exit_on_error "failed to clean up previous distribution package."
        fi
        if [ -e "$M_CONF_TMPDIR/osxfuse-dist-"* ]
        then
            m_warn "removing unrecognized version of distribution package"
            m_set_suprompt "to remove unrecognized version of platform-specific package"
            sudo -p "$m_suprompt" rm -rf "$M_CONF_TMPDIR/osxfuse-dist-"*
            m_exit_on_error "failed to clean up unrecognized version of distribution package."
        fi
    else
        if [ -e "$md_osxfuse_out/$M_PKGNAME_OSXFUSE" ]
        then
            echo >$m_stdout
            m_log "succeeded (shortcircuited), results in '$md_osxfuse_out'."
            echo >$m_stdout
            return 0
        fi
    fi

    if [ "$1" == "clean" ]
    then
        m_handler_core clean

        m_active_target="dist"

        m_set_platform

        rm -rf "$m_srcroot/prefpane/autoinstaller/build"
        m_log "cleaned internal subtarget autoinstaller"

        rm -rf "$m_srcroot/prefpane/build"
        m_log "cleaned internal subtarget prefpane"

        return 0
    fi

    m_log "initiating Universal build of OSXFUSE"

    # Create OSXFUSE subpackages
    #

    pushd . >/dev/null 2>/dev/null

    m_handler_core

    popd >/dev/null 2>/dev/null

    m_active_target="dist"

    m_platform="${M_PLATFORMS_REALISTIC%% *}"
    m_set_platform

    m_log "configuration is '$m_configuration'"
    if [ "$m_developer" == "0" ]
    then
        m_log "packaging flavor is 'Mainstream'"
    else
        m_log "packaging flavor is 'Developer Prerelease'"
    fi

    # Autoinstaller
    #

    local md_ai_builddir="$m_srcroot/prefpane/autoinstaller/build"

    if [ "$m_shortcircuit" != "1" ]
    then
        rm -rf "$md_ai_builddir"
        # ignore any errors
    fi

    m_log "building the OSXFUSE autoinstaller"

    pushd "$m_srcroot/prefpane/autoinstaller" >/dev/null 2>/dev/null
    m_exit_on_error "cannot access the autoinstaller source."
    xcodebuild -configuration "$m_configuration" -target "Build All" GCC_VERSION="$m_compiler" ARCHS="$m_archs" VALID_ARCHS="ppc i386 x86_64" SDKROOT="$m_usdk_dir" MACOSX_DEPLOYMENT_TARGET="$m_platform" >$m_stdout 2>$m_stderr
    m_exit_on_error "xcodebuild cannot build configuration $m_configuration for subtarget autoinstaller."
    popd >/dev/null 2>/dev/null

    local md_ai="$md_ai_builddir/$m_configuration/autoinstall-osxfuse-core"
    if [ ! -x "$md_ai" ]
    then
        false
        m_exit_on_error "cannot find autoinstaller '$md_ai'."
    fi
    local md_plistsigner="$md_ai_builddir/$m_configuration/plist_signer"
    if [ ! -x "$md_plistsigner" ]
    then
        false
        m_exit_on_error "cannot find plist signer '$md_plistsigner'."
    fi

    # Build the preference pane
    #
    local md_pp_builddir="$m_srcroot/prefpane/build"

    if [ "$m_shortcircuit" != "1" ]
    then
        rm -rf "$md_pp_builddir"
        # ignore any errors
    fi

    m_log "building the OSXFUSE prefpane"

    pushd "$m_srcroot/prefpane" >/dev/null 2>/dev/null
    m_exit_on_error "cannot access the prefpane source."
    xcodebuild -configuration "$m_configuration" -target "OSXFUSE" GCC_VERSION="$m_compiler" ARCHS="$m_archs" SDKROOT="$m_usdk_dir" MACOSX_DEPLOYMENT_TARGET="$m_platform" >$m_stdout 2>$m_stderr
    m_exit_on_error "xcodebuild cannot build configuration $m_configuration for subtarget prefpane."
    popd >/dev/null 2>/dev/null

    local md_pp="$md_pp_builddir/$m_configuration/OSXFUSE.prefPane"
    if [ ! -d "$md_pp" ]
    then
        false
        m_exit_on_error "cannot find preference pane."
    fi

    cp "$md_ai" "$md_pp/Contents/MacOS"
    m_exit_on_error "cannot copy the autoinstaller to the prefpane bundle."

    # Build the container
    #

    m_log "building '$M_PKGNAME_OSXFUSE'"

    mkdir -p "$md_osxfuse_out"
    m_exit_on_error "cannot create directory '$md_osxfuse_out'."

    mkdir -p "$md_osxfuse_root"
    m_exit_on_error "cannot create directory '$md_osxfuse_root'."

    m_log "copying generic container package payload"
    mkdir -p "$md_osxfuse_root/Library/PreferencePanes"
    m_exit_on_error "cannot make directory '$md_osxfuse_root/Library/PreferencePanes'."
    cp -R "$md_pp" "$md_osxfuse_root/Library/PreferencePanes/"
    m_exit_on_error "cannot copy the prefpane to '$md_osxfuse_root/Library/PreferencePanes/'."
    m_set_suprompt "to chown '$md_osxfuse_root/'."
    sudo -p "$m_suprompt" chown -R root:wheel "$md_osxfuse_root/"

    # Build Preference Pane installer package
    m_log "building installer package '$M_PKGNAME_PREFPANE'"

    m_build_pkg "$m_release_full" "$m_srcroot/support/InstallerPackages/$M_PKGBASENAME_PREFPANE" "$md_osxfuse_root" "$M_PKGID_PREFPANE" "$M_PKGNAME_PREFPANE" "/" "$md_osxfuse_out"
    m_exit_on_error "cannot create '$M_PKGNAME_PREFPANE'."

    # Build OSXFUSE installer package
    #
    cp -R "$m_srcroot/support/InstallerPackages/$M_PKGBASENAME_OSXFUSE" "$md_osxfuse_out/OSXFUSE"
    m_exit_on_error "cannot copy the packaging files for package '$M_PKGNAME_OSXFUSE'."

    local md_dist_choices_outline;

    local ms_core_out="$M_CONF_TMPDIR/osxfuse-core-$m_release_full"
    if [ ! -d "$ms_core_out" ]
    then
        false
        m_exit_on_error "cannot access directory '$ms_core_out'."
    fi

    pkgutil --expand "$ms_core_out/$M_PKGNAME_CORE" "$md_osxfuse_out/OSXFUSE/$M_PKGNAME_CORE"
    m_exit_on_error "cannot expand flat package '$M_PKGNAME_CORE'."

    pkgutil --expand "$ms_core_out/$M_PKGNAME_MACFUSE" "$md_osxfuse_out/OSXFUSE/$M_PKGNAME_MACFUSE"
    m_exit_on_error "cannot expand flat package '$M_PKGNAME_MACFUSE'."

    pkgutil --expand "$md_osxfuse_out/$M_PKGNAME_PREFPANE" "$md_osxfuse_out/OSXFUSE/$M_PKGNAME_PREFPANE"
    m_exit_on_error "cannot expand flat package '$M_PKGNAME_PREFPANE'."

    find "$md_osxfuse_out/OSXFUSE" -name ".DS_Store" -exec rm -f '{}' \;
    m_exit_on_error "cannot remove '.DS_Store' files from package '$M_PKGNAME_OSXFUSE'."

    local md_dist_out="$md_osxfuse_out/OSXFUSE/Distribution"
    local md_dist_choices="${M_PKGBASENAME_CORE}:${M_PKGNAME_CORE};${M_PKGBASENAME_PREFPANE}:${M_PKGNAME_PREFPANE};${M_PKGBASENAME_MACFUSE}:${M_PKGNAME_MACFUSE}"

cat >> "$md_dist_out" <<__END_DISTRIBUTION
<?xml version="1.0" encoding="UTF-8"?>
<installer-gui-script minSpecVersion="1.0">
    <title>FUSE for OS X (OSXFUSE)</title>
    <background file="background.png" scaling="none" alignment="center"/>
    <welcome file="Welcome.rtf"/>
    <license file="License.rtf"/>
    <options customize="always" rootVolumeOnly="true"/>
    <choices-outline>
__END_DISTRIBUTION
    m_exit_on_error "cannot write file 'Distribution' for package '$M_PKGNAME_OSXFUSE'."

    OLD_IFS="$IFS"
    IFS=";"
    for i in $md_dist_choices
    do
        local md_dist_choice_name="${i%%:*}"

cat >> "$md_dist_out" <<__END_DISTRIBUTION
        <line choice="$md_dist_choice_name"/>
__END_DISTRIBUTION
        m_exit_on_error "cannot write file 'Distribution' for package '$M_PKGNAME_OSXFUSE'."
    done
    IFS="$OLD_IFS"

cat >> "$md_dist_out" <<__END_DISTRIBUTION
    </choices-outline>
__END_DISTRIBUTION
    m_exit_on_error "cannot write file 'Distribution' for package '$M_PKGNAME_OSXFUSE'."

    OLD_IFS="$IFS"
    IFS=";"
    for i in $md_dist_choices
    do
        IFS="$OLD_IFS"

        local md_dist_choice_name="${i%%:*}"
        local md_dist_choice_packages="${i##*:}"

        local md_dist_choice_name_uc=`echo "$md_dist_choice_name" | tr '[:lower:]' '[:upper:]'`

cat >> "$md_dist_out" <<__END_DISTRIBUTION
    <choice id="$md_dist_choice_name"
        title="${md_dist_choice_name_uc}_TITLE"
        description="${md_dist_choice_name_uc}_DESCRIPTION"
        start_selected="isChoiceSelected('$md_dist_choice_name')"
        start_enabled="isChoiceEnabled('$md_dist_choice_name')"
        visible="isChoiceVisible('$md_dist_choice_name')">
__END_DISTRIBUTION
            m_exit_on_error "cannot write file 'Distribution' for package '$M_PKGNAME_OSXFUSE'."

        IFS=","
        for package in $md_dist_choice_packages
        do
            local md_dist_choice_pkg_path="$md_osxfuse_out/OSXFUSE/$package"
            local md_dist_choice_pkg_relpath="#$package"

            if [ ! -e "$md_dist_choice_pkg_path" ]
            then
                false
                m_exit_on_error "cannot find package '$package'."
            fi

            local md_dist_choice_pkg_id=`perl -ne '/<pkg-info[^>]*\sidentifier="([^"]+)"/ && print $1' "$md_dist_choice_pkg_path/PackageInfo"`
            m_exit_on_error "cannot extract property 'id' of '$package' for platform '$platform'."

            local md_dist_choice_pkg_size=`perl -ne '/<payload[^>]*\sinstallKBytes="([^"]+)"/ && print $1' "$md_dist_choice_pkg_path/PackageInfo"`
            m_exit_on_error "cannot extract property 'size' of '$package' for platform '$platform'."

            local md_dist_choice_pkg_version=`perl -ne '/<pkg-info[^>]*\sversion="([^"]+)"/ && print $1' "$md_dist_choice_pkg_path/PackageInfo"`
            m_exit_on_error "cannot extract property 'version' of '$package' for platform '$platform'."

            local md_dist_choice_pkg_auth=`perl -ne '/<pkg-info[^>]*\sauth="([^"]+)"/ && print $1' "$md_dist_choice_pkg_path/PackageInfo"`
            m_exit_on_error "cannot extract property 'auth' of '$package' for platform '$platform'."

cat >> "$md_dist_out" <<__END_DISTRIBUTION
        <pkg-ref id="$md_dist_choice_pkg_id"
            installKBytes="$md_dist_choice_pkg_size"
            version="$md_dist_choice_pkg_version"
            auth="$md_dist_choice_pkg_auth">$md_dist_choice_pkg_relpath</pkg-ref>
__END_DISTRIBUTION
            m_exit_on_error "cannot write file 'Distribution' for package '$M_PKGNAME_OSXFUSE'."
        done
        IFS="$OLD_IFS"

cat >> "$md_dist_out" <<__END_DISTRIBUTION
    </choice>
__END_DISTRIBUTION
        m_exit_on_error "cannot write file 'Distribution' for package '$M_PKGNAME_OSXFUSE'."

        IFS=";"
    done
    IFS="$OLD_IFS"

    local md_dist_productversion
    for platform in $M_PLATFORMS
    do
        md_dist_productversion=${md_dist_productversion:+"$md_dist_productversion || "}"isProductVersion('$platform')"
    done

cat >> "$md_dist_out" <<__END_DISTRIBUTION
    <installation-check script='installationCheck()'/>
    <script><![CDATA[
        function isProductVersion(version)
        {
            return system.version.ProductVersion.slice(0, version.length) == version;
        }
        function getChoice(package)
        {
            return choices[package];
        }

        function installationCheck()
        {
            if ($md_dist_productversion) return true;

            my.result.type = 'Fatal';
            my.result.message = system.localizedString('ERROR_OSXVERSION');
            return false;
        }
        function choiceConflictCheck(package)
        {
            if (package == '$M_PKGBASENAME_MACFUSE')
            {
                return system.files.fileExistsAtPath(
                           '/Library/Filesystems/fusefs.fs/Contents/Info.plist');
            }
            return false;
        }

        function isPackageInstalled()
        {
            return getChoice('$M_PKGBASENAME_CORE').packageUpgradeAction != 'clean';
        }

        function isChoiceDefaultSelected(package)
        {
            switch (package)
            {
                case '$M_PKGBASENAME_CORE': return true;
                case '$M_PKGBASENAME_PREFPANE': return true;
                default: return false;
            }
        }
        function isChoiceDefaultEnabled(package)
        {
            switch (package)
            {
                case '$M_PKGBASENAME_CORE': return false;
                default: return true;
            }
        }
        function isChoiceInstalled(package)
        {
            return getChoice(package).packageUpgradeAction != 'clean';
        }
        function isChoiceRequired(package)
        {
            return isChoiceInstalled(package) && !choiceConflictCheck(package);
        }
        function isChoiceSelected(package)
        {
            return (!isPackageInstalled() && isChoiceDefaultSelected(package)) ||
                   isChoiceRequired(package);
        }
        function isChoiceEnabled(package)
        {
            return isChoiceDefaultEnabled(package) && !isChoiceRequired(package);
        }
        function isChoiceVisible(package)
        {
            return true;
        }
    ]]></script>
</installer-gui-script>
__END_DISTRIBUTION
    m_exit_on_error "cannot write file 'Distribution' for package '$M_PKGNAME_OSXFUSE'."

    m_log "flatten installer package '$M_PKGNAME_OSXFUSE'"

    pkgutil --flatten "$md_osxfuse_out/OSXFUSE" "$md_osxfuse_out/$M_PKGNAME_OSXFUSE"
    m_exit_on_error "cannot flatten package '$M_PKGNAME_OSXFUSE'."

    echo >$m_stdout
    m_log "succeeded, results in '$md_osxfuse_out'."
    echo >$m_stdout

    return 0
}

function m_handler_release()
{
    m_active_target="release"

    m_platform="$M_DEFAULT_PLATFORM"
    m_set_platform

    m_release_full=`awk '/#define[ \t]*OSXFUSE_VERSION_LITERAL/ {print $NF}' "$m_srcroot/common/fuse_version.h"`
    m_release=`echo "$m_release_full" | cut -d . -f 1,2`
    m_exit_on_error "cannot get OSXFUSE release version."

    local mr_osxfuse_out="$M_CONF_TMPDIR/osxfuse-release-$m_release_full"

    local mr_dmg_name="OSXFUSE-$m_release_full.dmg"
    local mr_dmg_path="$mr_osxfuse_out/$mr_dmg_name"

    if [ "$m_shortcircuit" != "1" ]
    then
        if [ -e "$mr_osxfuse_out" ]
        then
            m_set_suprompt "to remove a previously built release diskimage"
            sudo -p "$m_suprompt" rm -rf "$mr_osxfuse_out"
            m_exit_on_error "failed to clean up previous built release diskimage."
        fi
        if [ -e "$M_CONF_TMPDIR/osxfuse-release-"* ]
        then
            m_warn "removing unrecognized version of release diskimage"
            m_set_suprompt "to remove unrecognized version of release diskimage"
            sudo -p "$m_suprompt" rm -rf "$M_CONF_TMPDIR/osxfuse-release-"*
            m_exit_on_error "failed to clean up unrecognized version of release diskimagee."
        fi
    else
        if [ -e "$mr_dmg_path" ]
        then
            echo >$m_stdout
            m_log "succeeded (shortcircuited), results in '$mr_osxfuse_out'."
            echo >$m_stdout
            return 0
        fi
    fi

    if [ "$1" == "clean" ]
    then
        m_handler_dist clean
        local retval=$?

        m_active_target="release"

        m_log "cleaned"
        return $retval
    fi

    m_handler_dist

    m_platform="$M_DEFAULT_PLATFORM"
    m_set_platform

    local mr_dist_out="$M_CONF_TMPDIR/osxfuse-dist-$m_release_full"

    # Locate plistsigner and private key
    #

    m_log "locating plistsigner and private key"

    local mr_ai_builddir="$m_srcroot/prefpane/autoinstaller/build"
    local mr_ai="$mr_ai_builddir/$m_configuration/autoinstall-osxfuse-core"
    if [ ! -x "$mr_ai" ]
    then
        false
        m_exit_on_error "cannot find autoinstaller '$mr_ai'."
    fi
    local mr_plistsigner="$mr_ai_builddir/$m_configuration/plist_signer"
    if [ ! -x "$mr_plistsigner" ]
    then
        false
        m_exit_on_error "cannot find plist signer '$mr_plistsigner'."
    fi

    if [ -z "$m_plistsigner_key" ]
    then
        m_plistsigner_key="$HOME/.osxfuse_private_key"
    fi
    if [ ! -f "$m_plistsigner_key" ]
    then
        m_plistsigner_key="$M_PLISTSIGNER_TEST_KEY"
        m_warn "using test key to sign update rules files"
    fi
    if [ ! -f "$m_plistsigner_key" ]
    then
        false
        m_exit_on_error "cannot find private key '$m_plistsigner_key'."
    fi

    mkdir -p "$mr_osxfuse_out"
    m_exit_on_error "cannot make directory '$mr_osxfuse_out'."

    # Sign installer package
    #
    if [ -z "$m_signing_id" ]
    then
        m_signing_id="Developer ID Installer: `dscl . -read /Users/$USER RealName | tail -1 | cut -c 2-`"
    fi
    productsign --sign "$m_signing_id" "$mr_dist_out/$M_PKGNAME_OSXFUSE" "$mr_osxfuse_out/$M_PKGNAME_OSXFUSE"
    m_exit_on_error "cannot sign installer package with id '$m_signing_id'."

    # Create the distribution volume
    #
    local mr_volume_name="FUSE for OS X"
    local mr_scratch_dmg="$mr_osxfuse_out/osxfuse-scratch.dmg"
    hdiutil create -layout NONE -size 10m -fs HFS+ -fsargs "-c c=64,a=16,e=16" \
        -volname "$mr_volume_name" "$mr_scratch_dmg" >$m_stdout 2>$m_stderr
    m_exit_on_error "cannot create scratch OSXFUSE disk image."

    # Attach/mount the volume
    #
    hdiutil attach -private -nobrowse "$mr_scratch_dmg" >$m_stdout 2>$m_stderr
    m_exit_on_error "cannot attach scratch OSXFUSE disk image."

    local mr_volume_path="/Volumes/$mr_volume_name"

    # Copy over the license file
    #
    cp "$m_srcroot/support/DiskImage/License.rtf" "$mr_volume_path"
    if [ $? -ne 0 ]
    then
        hdiutil detach "$mr_volume_path" >$m_stdout 2>$m_stderr
        false
        m_exit_on_error "cannot copy OSXFUSE license to scratch disk image."
    fi

    xcrun SetFile -a E "$mr_volume_path/License.rtf"
    if [ $? -ne 0 ]
    then
        hdiutil detach "$mr_volume_path" >$m_stdout 2>$m_stderr
        false
        m_exit_on_error "cannot hide extension of 'License.rtf'."
    fi

    # Copy over the package
    #
    local mr_pkgname_installer="Install OSXFUSE $m_release.pkg"
    cp -pRX "$mr_osxfuse_out/$M_PKGNAME_OSXFUSE" "$mr_volume_path/$mr_pkgname_installer"
    if [ $? -ne 0 ]
    then
        hdiutil detach "$mr_volume_path" >$m_stdout 2>$m_stderr
        false
        m_exit_on_error "cannot copy '$M_PKGNAME_OSXFUSE' to scratch disk image."
    fi

    xcrun SetFile -a E "$mr_volume_path/$mr_pkgname_installer"
    if [ $? -ne 0 ]
    then
        hdiutil detach "$mr_volume_path" >$m_stdout 2>$m_stderr
        false
        m_exit_on_error "cannot hide extension of installer package."
    fi

    # Copy over the website link
    #
    cp "$m_srcroot/support/DiskImage/OSXFUSE Website.webloc" "$mr_volume_path"
    if [ $? -ne 0 ]
    then
        hdiutil detach "$mr_volume_path" >$m_stdout 2>$m_stderr
        false
        m_exit_on_error "cannot copy website link to scratch disk image."
    fi

    xcrun SetFile -a E "$mr_volume_path/OSXFUSE Website.webloc"
    if [ $? -ne 0 ]
    then
        hdiutil detach "$mr_volume_path" >$m_stdout 2>$m_stderr
        false
        m_exit_on_error "cannot hide extension of 'OXSFUSE Website.webloc'."
    fi

    # Create the .engine_install file
    #
    local mr_engine_install="$mr_volume_path/.engine_install"
    cat > "$mr_engine_install" <<__END_ENGINE_INSTALL
#!/bin/sh -p
/usr/sbin/installer -pkg "\$1/$mr_pkgname_installer" -target /
__END_ENGINE_INSTALL

    chmod +x "$mr_engine_install"
    m_exit_on_error "cannot set permissions on autoinstaller engine file."


    # Set the custom icon
    #
    cp -pRX "$m_srcroot/support/Images/osxfuse.icns" \
        "$mr_volume_path/.VolumeIcon.icns"
    if [ $? -ne 0 ]
    then
        hdiutil detach "$mr_volume_path" >$m_stdout 2>$m_stderr
        false
        m_exit_on_error "cannot copy custom volume icon to scratch disk image."
    fi

    xcrun SetFile -a C "$mr_volume_path"
    if [ $? -ne 0 ]
    then
        hdiutil detach "$mr_volume_path" >$m_stdout 2>$m_stderr
        false
        m_exit_on_error "cannot set custom volume icon on scratch disk image."
    fi

    # Set custom background
    #
    mkdir "$mr_volume_path/.background"
    if [ $? -ne 0 ]
    then
        hdiutil detach "$mr_volume_path" >$m_stdout 2>$m_stderr
        false
        m_exit_on_error "cannot make directory '.background' on scratch disk image."
    fi

    cp "$m_srcroot/support/DiskImage/background.png" "$mr_volume_path/.background/"
    if [ $? -ne 0 ]
    then
        hdiutil detach "$mr_volume_path" >$m_stdout 2>$m_stderr
        false
        m_exit_on_error "cannot copy background picture to scratch disk image."
    fi

    # Customize scratch image
    #
    echo '
        tell application "Finder"
            tell disk "'$mr_volume_name'"
                open
                set current view of container window to icon view
                set toolbar visible of container window to false
                set the bounds of container window to {0, 0, 500, 350}
                set theViewOptions to the icon view options of container window
                set arrangement of theViewOptions to not arranged
                set icon size of theViewOptions to 128
                set background picture of theViewOptions to file ".background:background.png"
                set position of item "License.rtf" of container window to {100, 230}
                set position of item "'$mr_pkgname_installer'" of container window to {250, 230}
                set position of item "OSXFUSE Website.webloc" of container window to {400, 230}
                close
                open
                update without registering applications
                close
            end tell
        end tell
    ' | osascript
    if [ $? -ne 0 ]
    then
        hdiutil detach "$mr_volume_path" >$m_stdout 2>$m_stderr
        false
        m_exit_on_error "cannot customize the scratch disk image."
    fi

    chmod -Rf go-w "$mr_volume_path"
    sync
    sync
    # ignore errors

    # Detach the volume.
    hdiutil detach "$mr_volume_path" >$m_stdout 2>$m_stderr
    if [ $? -ne 0 ]
    then
        false
        m_exit_on_error "cannot detach volume '$mr_volume_path'."
    fi

    # Convert to a read-only compressed dmg
    #
    hdiutil convert -imagekey zlib-level=9 -format UDZO "$mr_scratch_dmg" \
        -o "$mr_dmg_path" >$m_stdout 2>$m_stderr
    m_exit_on_error "cannot finalize OSXFUSE distribution disk image."

    rm -f "$mr_scratch_dmg"
    # ignore any errors

    m_log "building redistribution package"

    m_log "creating autoinstaller rules"

    # Make autoinstaller rules file
    #
    local mr_dmg_hash=$(openssl sha1 -binary "$mr_dmg_path" | openssl base64)
    local mr_dmg_size=$(stat -f%z "$mr_dmg_path")

    local mr_rules_plist="$mr_osxfuse_out/DeveloperRelease.plist"
    local mr_download_url="https://github.com/downloads/osxfuse/osxfuse/$mr_dmg_name"
    if [ "$m_developer" == "0" ]
    then
        mr_rules_plist="$mr_osxfuse_out/CurrentRelease.plist"
        mr_download_url="https://github.com/downloads/osxfuse/osxfuse/$mr_dmg_name"
    fi

cat > "$mr_rules_plist" <<__END_RULES_PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Rules</key>
  <array>
__END_RULES_PLIST

    for m_p in $M_PLATFORMS
    do
cat >> "$mr_rules_plist" <<__END_RULES_PLIST
    <dict>
      <key>ProductID</key>
      <string>$M_OSXFUSE_PRODUCT_ID</string>
      <key>Predicate</key>
      <string>SystemVersion.ProductVersion beginswith "$m_p" AND Ticket.version != "$m_release_full"</string>
      <key>Version</key>
      <string>$m_release_full</string>
      <key>Codebase</key>
      <string>$mr_download_url</string>
      <key>Hash</key>
      <string>$mr_dmg_hash</string>
      <key>Size</key>
      <string>$mr_dmg_size</string>
    </dict>
__END_RULES_PLIST
    done

cat >> "$mr_rules_plist" <<__END_RULES_PLIST
  </array>
</dict>
</plist>
__END_RULES_PLIST

    # Sign the output rules
    #

    m_log "signing autoinstaller rules with key '$m_plistsigner_key'"

    m_set_suprompt "to sign the rules file"
    sudo -p "$m_suprompt" \
        "$mr_plistsigner" --sign --key "$m_plistsigner_key" \
            "$mr_rules_plist" >$m_stdout 2>$m_stderr
    m_exit_on_error "cannot sign the rules file '$mr_rules_plist' with key '$m_plistsigner_key'."

    echo >$m_stdout
    m_log "succeeded, results in '$mr_osxfuse_out'."
    echo >$m_stdout

    return 0
}

function m_handler_osxfusefs()
{
    m_active_target="osxfusefs"

    local support_dir="$m_srcroot"/support
    if [ ! -d "$support_dir" ]
    then
        false
        m_exit_on_error "cannot access directory '$support_dir'."
    fi

    local kernel_dir="$m_srcroot"/kext
    if [ ! -d "$kernel_dir" ]
    then
        false
        m_exit_on_error "cannot access directory '$kernel_dir'."
    fi

    local ms_osxfuse_version=`awk '/#define[ \t]*OSXFUSE_VERSION_LITERAL/ {print $NF}' "$m_srcroot"/common/fuse_version.h`
    m_exit_on_error "cannot get platform-specific OSXFUSE version."

    local ms_osxfuse_name="`awk '/#define[ \t]*OSXFUSE_NAME_LITERAL/ {print $NF}' "$m_srcroot/common/fuse_version.h"`"
    m_exit_on_error "cannot get name."

    local ms_osxfuse_namespace=`awk '/#define[ \t]*OSXFUSE_IDENTIFIER_LITERAL/ {print $NF}' "$m_srcroot/common/fuse_version.h"`
    m_exit_on_error "cannot get OSXFUSE namespace."

    local ms_osxfuse_out="$M_CONF_TMPDIR/osxfuse-osxfusefs-$ms_osxfuse_version"

    if [ -e "$ms_osxfuse_out" ]
    then
        m_set_suprompt "to remove a previously built package"
        sudo -p "$m_suprompt" rm -rf "$ms_osxfuse_out"
        m_exit_on_error "failed to clean up previously built package."
    fi
    if [ -e "$M_CONF_TMPDIR/osxfuse-osxfusefs-"* ]
    then
        m_warn "removing unrecognized version of package"
        m_set_suprompt "to remove unrecognized version of package"
        sudo -p "$m_suprompt" rm -rf "$M_CONF_TMPDIR/osxfuse-osxfusefs-"*
        m_exit_on_error "failed to clean up unrecognized version of package."
    fi

    if [ "$1" == "clean" ]
    then
        for m_p in $M_PLATFORMS_REALISTIC
        do
            m_platform="$m_p"
            m_handler_kext clean
        done

        m_active_target="osxfusefs"
        rm -rf "$support_dir/build/"

        m_log "cleaned"
        return 0
    fi

    if [ "$m_shortcircuit" != "1" ]
    then
        rm -rf "$support_dir/build/"
    fi

    cd "$support_dir"
    m_exit_on_error "failed to access the bundle source directory '$support_dir'."

    m_log "building OSXFUSE file system bundle"

    m_platform="${M_PLATFORMS_REALISTIC%% *}"
    m_set_platform


    xcodebuild -project "osxfusefs.xcodeproj" -configuration "$m_configuration" -target "osxfuse.fs" GCC_VERSION="$m_compiler" ARCHS="$m_archs" SDKROOT="$m_usdk_dir" MACOSX_DEPLOYMENT_TARGET="$m_platform" OSXFUSE_NAME="$ms_osxfuse_name" ENABLE_MACFUSE_MODE="$M_MACFUSE_MODE" BUNDLE_IDENTIFIER_PREFIX="$ms_osxfuse_namespace" >$m_stdout 2>$m_stderr

    m_exit_on_error "xcodebuild cannot build configuration $m_configuration."
    cd "$m_srcroot"

    local ms_built_products_dir="$support_dir/build/$m_configuration/"
    if [ ! -d "$ms_built_products_dir" ]
    then
        m_exit_on_error "cannot find built products directory."
    fi

    mkdir -p "$ms_osxfuse_out"
    m_exit_on_error "cannot make directory '$ms_osxfuse_out'."

    cp -pRX "$ms_built_products_dir/$M_FSBUNDLE_NAME" "$ms_osxfuse_out/$M_FSBUNDLE_NAME"
    m_exit_on_error "cannot copy file system bundle to destination."

    local ms_load_osxfuse="$ms_osxfuse_out/$M_FSBUNDLE_NAME/Contents/Resources/load_osxfuse"
    if [[ -f "$ms_load_osxfuse" ]]
    then
        m_set_suprompt "to setuid 'load_osxfuse'"
        sudo -p "$m_suprompt" chmod u+s "$ms_osxfuse_out/$M_FSBUNDLE_NAME/Contents/Resources/load_osxfuse"
        m_exit_on_error "cannot setuid 'load_osxfuse'."
    fi

    # Build kernel extensions
    #

    cd "$kernel_dir"
    m_exit_on_error "failed to access the kext source directory '$kernel_dir'."

    local -a md_plr=($M_PLATFORMS_REALISTIC)
    local -a md_pl=($M_PLATFORMS)
    j=0
    k=0
    while [[ $k -lt ${#md_pl[@]} ]]
    do
        if [[ $(( j+1 )) -lt ${#md_plr[@]} ]]
        then
            m_version_compare "${md_plr[$(( j+1 ))]}" "${md_pl[$k]}"
            if [[ $? -ne 2 ]]
            then
                (( j++ ))
            fi
        fi

        m_p="${md_pl[$k]}"
        m_pr="${md_plr[$j]}"

        if [ "$m_p" = "$m_pr" ]
        then
            pushd . >/dev/null 2>/dev/null
            m_platform="$m_p"
            m_handler_kext
            popd >/dev/null 2>/dev/null

            m_active_target="osxfusefs"

            local ms_kext_out="$M_CONF_TMPDIR/osxfuse-kext-$m_p-$ms_osxfuse_version"
            if [ ! -d "$ms_kext_out" ]
            then
                false
                m_exit_on_error "cannot access directory '$ms_kext_out'."
            fi

            mkdir -p "$ms_osxfuse_out/$M_FSBUNDLE_NAME/Contents/Resources/$m_p"
            m_exit_on_error "cannot make directory '$ms_osxfuse_out/$M_FSBUNDLE_NAME/Contents/Resources/$m_p'."

            cp -pRX "$ms_kext_out/$M_KEXT_NAME" "$ms_osxfuse_out/$M_FSBUNDLE_NAME/Contents/Resources/$m_p/$M_KEXT_NAME"
            m_exit_on_error "cannot copy '$M_KEXT_NAME' for platform '$m_p' to destination."
        else
            ln -s "$m_pr" "$ms_osxfuse_out/$M_FSBUNDLE_NAME/Contents/Resources/$m_p"
            m_exit_on_error "cannot make symlink '$m_p' -> '$m_pr'"
        fi

        (( k++ ))
    done

    m_set_suprompt "to set permissions on newly built file system bundle"
    sudo -p "$m_suprompt" chown -R root:wheel "$ms_osxfuse_out/$M_FSBUNDLE_NAME"
    m_exit_on_error "cannot set permissions on newly built file system bundle."

    echo >$m_stdout
    m_log "succeeded, results in '$ms_osxfuse_out'."
    echo >$m_stdout

    return 0
}

# Build kernel extension
#
function m_handler_kext()
{
    m_active_target="kext"

    m_set_platform

    local kernel_dir="$m_srcroot"/kext
    if [ ! -d "$kernel_dir" ]
    then
        false
        m_exit_on_error "cannot access directory '$kernel_dir'."
    fi

    if [ "$m_shortcircuit" != "1" ]
    then
        rm -rf "$kernel_dir/build/"
    fi

    local ms_os_version="$m_platform"
    local ms_osxfuse_version=`awk '/#define[ \t]*OSXFUSE_VERSION_LITERAL/ {print $NF}' "$m_srcroot"/common/fuse_version.h`
    m_exit_on_error "cannot get platform-specific OSXFUSE version."

    local ms_osxfuse_name="`awk '/#define[ \t]*OSXFUSE_NAME_LITERAL/ {print $NF}' "$m_srcroot/common/fuse_version.h"`"
    m_exit_on_error "cannot get name."

    M_KEXT_NAME="$ms_osxfuse_name.kext"

    local ms_osxfuse_out="$M_CONF_TMPDIR/osxfuse-kext-$ms_os_version-$ms_osxfuse_version"

    if [ "$m_shortcircuit" != "1" ]
    then
        if [ -e "$ms_osxfuse_out" ]
        then
            m_set_suprompt "to remove a previously built platform-specific package"
            sudo -p "$m_suprompt" rm -rf "$ms_osxfuse_out"
            m_exit_on_error "failed to clean up previous platform-specific OSXFUSE build."
        fi
        if [ -e "$M_CONF_TMPDIR/osxfuse-kext-$ms_os_version-"* ]
        then
            m_warn "removing unrecognized version of platform-specific package"
            m_set_suprompt "to remove unrecognized version of platform-specific package"
            sudo -p "$m_suprompt" rm -rf "$M_CONF_TMPDIR/osxfuse-kext-$ms_os_version-"*
            m_exit_on_error "failed to clean up unrecognized version of platform-specific package."
        fi
    else
        if [ -e "$ms_osxfuse_out/$M_KEXT_NAME" ]
        then
            echo >$m_stdout
            m_log "succeeded (shortcircuited), results in '$ms_osxfuse_out'."
            echo >$m_stdout
            return 0
        fi
    fi

    if [ "$1" == "clean" ]
    then
        local retval=$?
        m_log "cleaned (platform $m_platform)"
        return $retval
    fi

    m_log "initiating Universal build for $m_platform"

    cd "$kernel_dir"
    m_exit_on_error "failed to access the kext source directory '$kernel_dir'."

    m_log "building OSXFUSE kernel extension"

    xcodebuild -configuration "$m_configuration" -target osxfuse GCC_VERSION="$m_compiler" ARCHS="$m_archs" SDKROOT="$m_usdk_dir" MACOSX_DEPLOYMENT_TARGET="$m_platform" OSXFUSE_NAME="$ms_osxfuse_name" ENABLE_MACFUSE_MODE="$M_MACFUSE_MODE" >$m_stdout 2>$m_stderr

    m_exit_on_error "xcodebuild cannot build configuration $m_configuration."

    # Go for it

    local ms_project_dir="$kernel_dir"

    local ms_built_products_dir="$kernel_dir/build/$m_configuration/"
    if [ ! -d "$ms_built_products_dir" ]
    then
        m_exit_on_error "cannot find built products directory."
    fi

    mkdir -p "$ms_osxfuse_out"
    m_exit_on_error "cannot make directory '$ms_osxfuse_out'."

    cp -pRX "$ms_built_products_dir/$M_KEXT_NAME" "$ms_osxfuse_out/$M_KEXT_NAME"
    m_exit_on_error "cannot copy '$M_KEXT_NAME' to destination."

    if [[ -n "$m_signing_id" ]]
    then
        codesign -f -s "$m_signing_id" "$ms_osxfuse_out/$M_KEXT_NAME"
        m_exit_on_error "cannot sign kernel extension."
    fi

    cp -pRX "$ms_built_products_dir/Debug" "$ms_osxfuse_out/Debug"
    m_exit_on_error "cannot copy 'Debug' to destination."

    m_set_suprompt "to set permissions on newly built kernel extension"
    sudo -p "$m_suprompt" chown -R root:wheel "$ms_osxfuse_out/$M_KEXT_NAME"
    m_exit_on_error "cannot set permissions on newly built kernel extension."

    echo >$m_stdout
    m_log "succeeded, results in '$ms_osxfuse_out'."
    echo >$m_stdout

    return 0
}

# Build a platform-specific distribution package
#
function m_handler_core()
{
    m_active_target="core"

    m_platform="${M_PLATFORMS_REALISTIC%% *}"
    m_set_platform

    local lib_dir="$m_srcroot"/fuse
    if [ ! -d "$lib_dir" ]
    then
        false
        m_exit_on_error "cannot access directory '$lib_dir'."
    fi
    local lib_dir_mf="$m_srcroot"/fuse-macfuse
    if [ ! -d "$lib_dir_mf" ]
    then
        false
        m_exit_on_error "cannot access directory '$lib_dir_mf'."
    fi

    local kernel_dir="$m_srcroot"/kext
    if [ ! -d "$kernel_dir" ]
    then
        false
        m_exit_on_error "cannot access directory '$kernel_dir'."
    fi

    if [ "$m_shortcircuit" != "1" ]
    then
        rm -rf "$kernel_dir/build/"
        rm -rf "$m_srcroot/framework/build/"
    fi

    local ms_os_version="$m_platform"
    local ms_osxfuse_version=`awk '/#define[ \t]*OSXFUSE_VERSION_LITERAL/ {print $NF}' "$m_srcroot"/common/fuse_version.h`
    m_exit_on_error "cannot get platform-specific OSXFUSE version."

    local ms_osxfuse_out="$M_CONF_TMPDIR/osxfuse-core-$ms_osxfuse_version"
    local ms_osxfuse_build="$ms_osxfuse_out/build/"
    local ms_osxfuse_root="$ms_osxfuse_out/osxfuse/"
    local ms_macfuse_root="$ms_osxfuse_out/macfuse/"

    if [ "$m_shortcircuit" != "1" ]
    then
        if [ -e "$ms_osxfuse_out" ]
        then
            m_set_suprompt "to remove a previously built core package"
            sudo -p "$m_suprompt" rm -rf "$ms_osxfuse_out"
            m_exit_on_error "failed to clean up previous OSXFUSE core build."
        fi
        if [ -e "$M_CONF_TMPDIR/osxfuse-core-"* ]
        then
            m_warn "removing unrecognized version of core package"
            m_set_suprompt "to remove unrecognized version of core package"
            sudo -p "$m_suprompt" rm -rf "$M_CONF_TMPDIR/osxfuse-core-"*
            m_exit_on_error "failed to clean up unrecognized version of core package."
        fi
    else
        if [ -e "$ms_osxfuse_out/$M_PKGNAME_CORE" -a -e "$ms_osxfuse_out/$M_PKGNAME_MACFUSE" ]
        then
            echo >$m_stdout
            m_log "succeeded (shortcircuited), results in '$ms_osxfuse_out'."
            echo >$m_stdout
            return 0
        fi
    fi

    if [ "$1" == "clean" ]
    then
        m_handler_osxfusefs clean
        local retval=$?

        m_active_target="core"

        m_log "cleaned"
        return $retval
    fi

    m_log "initiating Universal build for $m_platform"

    # Build file system bundle
    #

    m_handler_osxfusefs

    local ms_osxfusefs_out="$M_CONF_TMPDIR/osxfuse-osxfusefs-$ms_osxfuse_version"
    if [ ! -d "$ms_osxfusefs_out" ]
    then
        false
        m_exit_on_error "cannot access directory '$ms_osxfusefs_out'."
    fi

    # Go for it

    m_active_target="core"

    m_platform="${M_PLATFORMS_REALISTIC%% *}"
    m_set_platform

    mkdir -p "$ms_osxfuse_build"
    m_exit_on_error "cannot make new build directory '$ms_osxfuse_build'."

    mkdir -p "$ms_osxfuse_root"
    m_exit_on_error "cannot make directory '$ms_osxfuse_root'."

    mkdir -p "$ms_osxfuse_root/Library/Filesystems/"
    m_exit_on_error "cannot make directory '$ms_osxfuse_root/Library/Filesystems/'."

    mkdir -p "$ms_osxfuse_root/Library/Frameworks/"
    m_exit_on_error "cannot make directory '$ms_osxfuse_root/Library/Frameworks/'."

    mkdir -p "$ms_macfuse_root/Library/Frameworks/"
    m_exit_on_error "cannot make directory '$ms_osxfuse_root/Library/Frameworks/'."

    mkdir -p "$ms_osxfuse_root/usr/local/lib/"
    m_exit_on_error "cannot make directory '$ms_osxfuse_root/usr/local/lib/'."

    mkdir -p "$ms_macfuse_root/usr/local/lib/"
    m_exit_on_error "cannot make directory '$ms_osxfuse_root/usr/local/lib/'."

    mkdir -p "$ms_osxfuse_root/usr/local/include/"
    m_exit_on_error "cannot make directory '$ms_osxfuse_root/usr/local/include/'."

    mkdir -p "$ms_osxfuse_root/usr/local/lib/pkgconfig/"
    m_exit_on_error "cannot make directory '$ms_osxfuse_root/usr/local/lib/pkgconfig/'."

    local ms_bundle_dir_generic="/Library/Filesystems/$M_FSBUNDLE_NAME"
    local ms_bundle_dir="$ms_osxfuse_root/$ms_bundle_dir_generic"
    local ms_bundle_resources_dir="$ms_bundle_dir/Contents/Resources"

    cp -pRX "$ms_osxfusefs_out/$M_FSBUNDLE_NAME" "$ms_bundle_dir"
    m_exit_on_error "cannot copy '$M_FSBUNDLE_NAME' to destination."

    cp -pRX "$m_srcroot/support/uninstall_osxfuse.sh" "$ms_bundle_resources_dir/uninstall_osxfuse.sh"
    m_exit_on_error "cannot copy 'uninstall_osxfuse.sh' to destination."

    cp -pRX "$m_srcroot/support/uninstall_macfuse.sh" "$ms_bundle_resources_dir/uninstall_macfuse.sh"
    m_exit_on_error "cannot copy 'uninstall_macfuse.sh' to destination."

    ln -s "/Library/PreferencePanes/OSXFUSE.prefPane/Contents/MacOS/autoinstall-osxfuse-core" "$ms_bundle_resources_dir/autoinstall-osxfuse-core"
    m_exit_on_error "cannot create legacy symlink '$ms_bundle_resources_dir/autoinstall-osxfuse-core'".

    # Build the user-space OSXFUSE library
    #

    m_log "building user-space OSXFUSE library"

    ms_deployment_target="$m_platform"
    m_platform="${M_PLATFORMS_REALISTIC%% *}"
    m_set_platform

    cp -pRX "$lib_dir" "$ms_osxfuse_build"
    m_exit_on_error "cannot copy OSXFUSE library source from '$lib_dir'."

    cd "$ms_osxfuse_build"/fuse
    m_exit_on_error "cannot access OSXFUSE library source in '$ms_osxfuse_build/fuse'."

    COMPILER="$m_compiler" ARCHS="$m_archs" SDKROOT="$m_usdk_dir" MACOSX_DEPLOYMENT_TARGET="$m_platform" ./darwin_configure.sh "$m_srcroot" >$m_stdout 2>$m_stderr
    m_exit_on_error "cannot configure OSXFUSE library source for compilation."

    xcrun make -j4 >$m_stdout 2>$m_stderr
    m_exit_on_error "make failed while compiling the OSXFUSE library."

    xcrun make install DESTDIR="$ms_osxfuse_root" >$m_stdout 2>$m_stderr
    m_exit_on_error "cannot prepare library build for installation."

    for f in "$ms_osxfuse_root"/usr/local/lib/libosxfuse*.dylib; do
        local source=`basename "$f"`
        local target="`echo \"$f\" | sed 's/libosxfuse/libosxfuse_i64/'`"
        ln -s "$source" "$target"
        m_exit_on_error "cannot create symlink '$target' -> '$source'."
    done
    ln -s libosxfuse.la "$ms_osxfuse_root/usr/local/lib/libosxfuse_i64.la"
    m_exit_on_error "cannot create symlink '$ms_osxfuse_root/usr/local/lib/libosxfuse.la' -> 'libosxfuse_i64.la'."

    ln -s osxfuse.pc "$ms_osxfuse_root/usr/local/lib/pkgconfig/fuse.pc"
    m_exit_on_error "cannot create symlink '$ms_osxfuse_root/usr/local/lib/pkgconfig/fuse.pc' -> 'osxfuse.pc'."

    # Generate dSYM bundle
    xcrun dsymutil "$ms_osxfuse_root"/usr/local/lib/libosxfuse.dylib
    m_exit_on_error "cannot generate debugging information for libosxfuse."

    # Build the user-space MacFUSE library
    #

    m_log "building user-space MacFUSE library"

    cp -pRX "$lib_dir_mf" "$ms_osxfuse_build/macfuse"
    m_exit_on_error "cannot copy OSXFUSE library source from '$lib_dir_mf'."

    cd "$ms_osxfuse_build"/macfuse
    m_exit_on_error "cannot access MacFUSE library source in '$ms_osxfuse_build/macfuse'."

    COMPILER="$m_compiler" ARCHS="$m_archs" SDKROOT="$m_usdk_dir" MACOSX_DEPLOYMENT_TARGET="$m_platform" ./darwin_configure.sh "$m_srcroot" >$m_stdout 2>$m_stderr
    m_exit_on_error "cannot configure MacFUSE library source for compilation."

    xcrun make -j4 >$m_stdout 2>$m_stderr
    m_exit_on_error "make failed while compiling the MacFUSE library."

    xcrun make install DESTDIR="$ms_macfuse_root" >$m_stdout 2>$m_stderr
    m_exit_on_error "cannot prepare library build for installation."

    ln -s libfuse.dylib "$ms_macfuse_root/usr/local/lib/libfuse.0.dylib"
    m_exit_on_error "cannot create compatibility symlink 'libfuse.0.dylib'."

    # Generate dSYM bundles
    xcrun dsymutil "$ms_macfuse_root"/usr/local/lib/libfuse.dylib
    m_exit_on_error "cannot generate debugging information for libfuse."
    xcrun dsymutil "$ms_macfuse_root"/usr/local/lib/libfuse_ino64.dylib
    m_exit_on_error "cannot generate debugging information for libfuse_ino64."

    # Build OSXFUSE.framework
    #

    m_log "building OSXFUSE Objective-C framework"

    cd "$m_srcroot/framework"
    m_exit_on_error "cannot access Objective-C framework directory."

    rm -rf build/
    m_exit_on_error "cannot remove previous build of OSXFUSE.framework."

    xcodebuild -configuration "$m_configuration" -target "OSXFUSE" GCC_VERSION="$m_compiler" ARCHS="$m_archs" SDKROOT="$m_usdk_dir" MACOSX_DEPLOYMENT_TARGET="$m_platform" OSXFUSE_BUILD_ROOT="$ms_osxfuse_root" OSXFUSE_BUNDLE_VERSION_LITERAL="$ms_osxfuse_version" >$m_stdout 2>$m_stderr
    m_exit_on_error "xcodebuild cannot build configuration '$m_configuration'."

    cp -pRX build/"$m_configuration"/*.framework "$ms_osxfuse_root/Library/Frameworks/"
    m_exit_on_error "cannot copy 'OSXFUSE.framework' to destination."

    mv "$ms_osxfuse_root"/usr/local/lib/*.dSYM "$ms_osxfuse_root"/Library/Frameworks/OSXFUSE.framework/Resources/Debug/
    mv "$ms_macfuse_root"/usr/local/lib/*.dSYM "$ms_osxfuse_root"/Library/Frameworks/OSXFUSE.framework/Resources/Debug/
#   mkdir -p "$ms_osxfuse_root/Library/Application Support/Developer/Shared/Xcode/Project Templates"
#   m_exit_on_error "cannot create directory for Xcode templates."
#   ln -s "/Library/Frameworks/OSXFUSE.framework/Resources/ProjectTemplates/" "$ms_osxfuse_root/Library/Application Support/Developer/Shared/Xcode/Project Templates/OSXFUSE"
#   m_exit_on_error "cannot create symlink for Xcode templates."

    # Link MacFUSE.framework back to OSXFUSE.framework
    #

    cp -pRX MacFUSE.framework "$ms_macfuse_root/Library/Frameworks/"
    m_exit_on_error "cannot copy 'MacFUSE.framework' to destination."

    sed -e "s/OSXFUSE_CORE_VERSION/$ms_osxfuse_version/" "MacFUSE.framework/Versions/A/Resources/Info.plist" > "$ms_macfuse_root/Library/Frameworks/MacFUSE.framework/Versions/A/Resources/Info.plist"
    m_exit_on_error "failed to process Info.plist of 'MacFUSE.framework'."

    # Change owner and mode of files and directory in package root
    #

    m_set_suprompt "to chown '$ms_osxfuse_root/*'"
    sudo -p "$m_suprompt" chown -R root:wheel "$ms_osxfuse_root"/*
    m_exit_on_error "cannot chown '$ms_osxfuse_root/*'."

    m_set_suprompt "to chown '$ms_macfuse_root/*'"
    sudo -p "$m_suprompt" chown -R root:wheel "$ms_macfuse_root"/*
    m_exit_on_error "cannot chown '$ms_macfuse_root/*'."

    m_set_suprompt "to setuid 'load_osxfuse'"
    sudo -p "$m_suprompt" chmod u+s "$ms_bundle_resources_dir/load_osxfuse"
    m_exit_on_error "cannot setuid 'load_osxfuse'."

    m_set_suprompt "to chown '$ms_osxfuse_root/Library/'"
    sudo -p "$m_suprompt" chown root:admin "$ms_osxfuse_root/Library/"
    m_exit_on_error "cannot chown '$ms_osxfuse_root/Library/'."

    m_set_suprompt "to chown '$ms_macfuse_root/Library/'"
    sudo -p "$m_suprompt" chown root:admin "$ms_macfuse_root/Library/"
    m_exit_on_error "cannot chown '$ms_macfuse_root/Library/'."

    m_set_suprompt "to chown '$ms_osxfuse_root/Library/Frameworks/"
    sudo -p "$m_suprompt" \
        chown -R root:admin "$ms_osxfuse_root/Library/Frameworks/"
    m_exit_on_error "cannot chown '$ms_osxfuse_root/Library/Frameworks/'."

    m_set_suprompt "to chown '$ms_macfuse_root/Library/Frameworks/"
    sudo -p "$m_suprompt" \
    chown -R root:admin "$ms_macfuse_root/Library/Frameworks/"
    m_exit_on_error "cannot chown '$ms_macfuse_root/Library/Frameworks/'."

    m_set_suprompt "to chmod '$ms_osxfuse_root/Library/Frameworks/'"
    sudo -p "$m_suprompt" chmod 0775 "$ms_osxfuse_root/Library/Frameworks/"
    m_exit_on_error "cannot chmod '$ms_osxfuse_root/Library/Frameworks/'."

    m_set_suprompt "to chmod '$ms_macfuse_root/Library/Frameworks/'"
    sudo -p "$m_suprompt" chmod 0775 "$ms_macfuse_root/Library/Frameworks/"
    m_exit_on_error "cannot chmod '$ms_macfuse_root/Library/Frameworks/'."

    m_set_suprompt "to chmod '$ms_osxfuse_root/Library/'"
    sudo -p "$m_suprompt" chmod 1775 "$ms_osxfuse_root/Library/"
    m_exit_on_error "cannot chmod '$ms_osxfuse_root/Library/'."

    m_set_suprompt "to chmod '$ms_macfuse_root/Library/'"
    sudo -p "$m_suprompt" chmod 1775 "$ms_macfuse_root/Library/"
    m_exit_on_error "cannot chmod '$ms_macfuse_root/Library/'."

    m_set_suprompt "to chmod files in '$ms_osxfuse_root/usr/local/lib/'"
    sudo -p "$m_suprompt" \
        find "$ms_osxfuse_root/usr/local/lib" -type l -depth 1 -exec chmod -h 755 '{}' \;
    m_exit_on_error "cannot chmod files in '$ms_osxfuse_root/usr/local/lib/'."

    m_set_suprompt "to chmod files in '$ms_macfuse_root/usr/local/lib/'"
    sudo -p "$m_suprompt" \
        find "$ms_macfuse_root/usr/local/lib" -type l -depth 1 -exec chmod -h 755 '{}' \;
    m_exit_on_error "cannot chmod files in '$ms_macfuse_root/usr/local/lib/'."

    m_set_suprompt "to chmod files in '$ms_osxfuse_root/Library/Frameworks/'"
    sudo -p "$m_suprompt" \
        find "$ms_osxfuse_root/Library/Frameworks/" -type l -exec chmod -h 755 '{}' \;
    # no exit upon error

    m_set_suprompt "to chmod files in '$ms_macfuse_root/Library/Frameworks/'"
    sudo -p "$m_suprompt" \
        find "$ms_macfuse_root/Library/Frameworks/" -type l -exec chmod -h 755 '{}' \;
    # no exit upon error

    cd "$ms_osxfuse_root"
    m_exit_on_error "cannot access directory '$ms_osxfuse_root'."

    cd "$ms_macfuse_root"
    m_exit_on_error "cannot access directory '$ms_macfuse_root'."

    # Create the OSXFUSE Installer Package
    #

    m_log "building installer package for $m_platform"

    m_platform="$ms_deployment_target"
    m_set_platform

    m_build_pkg "$ms_osxfuse_version" "$m_srcroot/support/InstallerPackages/$M_PKGBASENAME_CORE" "$ms_osxfuse_root" "$M_PKGID_CORE" "$M_PKGNAME_CORE" "/" "$ms_osxfuse_out"
    m_exit_on_error "cannot create '$M_PKGNAME_CORE'."

    m_build_pkg "$ms_osxfuse_version" "$m_srcroot/support/InstallerPackages/$M_PKGBASENAME_MACFUSE" "$ms_macfuse_root" "$M_PKGID_MACFUSE" "$M_PKGNAME_MACFUSE" "/" "$ms_osxfuse_out"
    m_exit_on_error "cannot create '$M_PKGNAME_MACFUSE'."

    echo >$m_stdout
    m_log "succeeded, results in '$ms_osxfuse_out'."
    echo >$m_stdout

    return 0
}

function m_validate_input()
{
    local mvi_found=
    local mvi_good=

    # Validate scratch directory
    if [ ! -d "$M_CONF_TMPDIR" ] || [ ! -w "$M_CONF_TMPDIR" ]
    then
        echo "M_CONF_TMPDIR (currently '$M_CONF_TMPDIR') must be set to a writeable directory."
        exit 2
    fi

    # Validate if platform was specified when it shouldn't have been
    #
    if [ "$m_platform" != "$M_DEFAULT_PLATFORM" ]
    then
        mvi_found="0"
        for m_p in $M_TARGETS_WITH_PLATFORM
        do
            if [ "$m_target" == "$m_p" ]
            then
                mvi_found="1"
                break
            fi
        done
        if [ "$mvi_found" == "0" ]
        then
            echo "Unknown argument or invalid combination of arguments."
            echo  "Try $0 -h for help."
            exit 2
        fi
    fi

    # Validate platform
    if [ "$m_platform" != "$M_DEFAULT_PLATFORM" ]
    then
        mvi_good="0"
        for m_p in $M_PLATFORMS
        do
            if [ "$m_platform" == "$m_p" ]
            then
                mvi_good="1"
                break
            fi
        done
        if [ "$mvi_good" == "0" ]
        then
            echo "Unknown platform '$m_platform'."
            echo "Valid platforms are: $M_PLATFORMS."
            exit 2
        fi
    fi

    # Validate target
    #
    if [ "$m_target" != "$M_DEFAULT_TARGET" ]
    then
        mvi_good="0"
        for m_t in $M_TARGETS
        do
            if [ "$m_target" == "$m_t" ]
            then
                mvi_good="1"
                break
            fi
        done
        if [ "$mvi_good" == "0" ]
        then
            echo "Unknown target '$m_target'."
            echo "Valid targets are: $M_TARGETS."
            exit 2
        fi
    fi

    # Validate configuration
    #
    mvi_good="0"
    for m_c in $M_CONFIGURATIONS
    do
        if [ "$m_configuration" == "$m_c" ]
        then
            mvi_good="1"
            break
        fi
    done
    if [ "$mvi_good" == "0" ]
    then
        echo "Unknown configuration '$m_configuration'."
        echo "Valid configurations are: $M_CONFIGURATIONS."
        exit 2
    fi

    if [ "$m_shortcircuit" == "1" ] && [ "$m_target" == "clean" ]
    then
       echo "Cleaning cannot be shortcircuited!"
       exit 2
    fi

    export OSXFUSE_MACFUSE_MODE=$M_MACFUSE_MODE

    return 0
}

function m_read_input()
{
    m_args=`getopt c:dhp:qst:v $*`

    if [ $? != 0 ]
    then
        echo "Try $0 -h for help."
        exit 2
    fi

    set -- $m_args

    for m_i
    do
        case "$m_i" in
        -c)
            m_configuration="$2"
            shift
            shift
            ;;
        -d)
            m_developer=1
            shift
            ;;
        -h)
            m_help
            exit 0
            ;;
        -p)
            m_platform="$2"
            shift
            shift
            ;;
        -q)
            m_stderr=/dev/null
            m_stdout=/dev/null
            shift
            ;;
        -s)
            m_shortcircuit="1"
            shift
            ;;
        -t)
            m_target="$2"
            shift
            shift
            ;;
        -v)
            m_version
            exit 0
            shift
            ;;
        -i)
            m_signing_id="$2"
            shift
            shift
            ;;
        -u)
            m_plistsigner_key="$2"
            shift
            shift
            ;;
        --)
            shift
            break
            ;;
        esac
    done
}

function m_version_compare()
{
    local _IFS="$IFS"; IFS="."

    local -a version1=( $1 )
    local -a version2=( $2 )

    IFS="$_IFS"

    local count
    if [[ ${#version1[@]} -lt ${#version2[@]} ]]
    then
        count=${#version2[@]}
    else
        count=${#version1[@]}
    fi

    local i
    for (( i=0; i < count; i++ ))
    do
        local t1=${version1[$i]:-0}
        local t2=${version2[$i]:-0}

        [[ $t1 -lt $t2 ]] && return 1
        [[ $t1 -gt $t2 ]] && return 2
    done
    return 0
}

function m_platform_realistic_add()
{
    local platform="$1"

    local _IFS="$IFS"; IFS=" "
    for p in $M_PLATFORMS
    do
        if [[ "$p" = "$platform" ]]
        then
            IFS="$_IFS"
            return
        fi
    done
    IFS="$_IFS"

    M_PLATFORMS_REALISTIC=${M_PLATFORMS_REALISTIC:+"$M_PLATFORMS_REALISTIC "}"$platform"
    m_platform_add "$platform"
}

function m_platform_add()
{
    local platform="$1"

    local _IFS="$IFS"; IFS=" "
    for p in $M_PLATFORMS
    do
        if [[ "$p" = "$platform" ]]
        then
            IFS="$_IFS"
            return
        fi
    done
    IFS="$_IFS"

    M_PLATFORMS=${M_PLATFORMS:+"$M_PLATFORMS "}"$platform"
}

function m_handler()
{
    case "$m_target" in

    "clean")
        m_handler_examples clean
        m_handler_lib clean
        m_handler_release clean
    ;;

    "release")
        m_handler_release
    ;;

    "dist")
        m_handler_dist
    ;;

    "osxfusefs")
        m_handler_osxfusefs
    ;;

    "kext")
        m_handler_kext
    ;;

    "examples")
        m_handler_examples
    ;;

    "lib")
        m_handler_lib
    ;;

    "reload")
        m_handler_reload
    ;;

    "core")
        m_handler_core
    ;;

    *)
        echo "Try $0 -h for help."
    ;;

    esac
}

# main()
# {
    M_ACTUAL_PLATFORM=`sw_vers -productVersion | cut -d . -f 1,2`
    m_exit_on_error "cannot determine actual platform"

    # Locace Xcode installations
    for m_xcodebuild in /*/usr/bin/xcodebuild /Applications/*.app/Contents/Developer/usr/bin/xcodebuild
    do
        m_xcode_root="${m_xcodebuild%/usr/bin/xcodebuild}"
        if [[ "$m_xcode_root" =~ "*"|" " || -L "$m_xcode_root" ]]
        then
            continue
        fi

        m_xcode_version=`DEVELOPER_DIR="$m_xcode_root" xcodebuild -version | grep "Xcode" | cut -f 2 -d " "`

        case $m_xcode_version in
            3.2*)
                m_version_compare $M_XCODE32_VERSION $m_xcode_version
                if [[ $? != 2 ]]
                then
                    M_XCODE32="$m_xcode_root"
                    M_XCODE32_VERSION=$m_xcode_version
                fi
                ;;
            4.0*)
                m_version_compare $M_XCODE40_VERSION $m_xcode_version
                if [[ $? != 2 ]]
                then
                    M_XCODE40="$m_xcode_root"
                    M_XCODE40_VERSION=$m_xcode_version
                fi
                ;;
            4.1*)
                m_version_compare $M_XCODE41_VERSION $m_xcode_version
                if [[ $? != 2 ]]
                then
                    M_XCODE41="$m_xcode_root"
                    M_XCODE41_VERSION=$m_xcode_version
                fi
                ;;
            4.2*)
                m_version_compare $M_XCODE42_VERSION $m_xcode_version
                if [[ $? != 2 ]]
                then
                    M_XCODE42="$m_xcode_root"
                    M_XCODE42_VERSION=$m_xcode_version
                fi
                ;;
            4.3*)
                m_version_compare $M_XCODE43_VERSION $m_xcode_version
                if [[ $? != 2 ]]
                then
                    M_XCODE43="$m_xcode_root"
                    M_XCODE43_VERSION=$m_xcode_version
                fi
                ;;
            4.4*)
                m_version_compare $M_XCODE44_VERSION $m_xcode_version
                if [[ $? != 2 ]]
                then
                    M_XCODE44="$m_xcode_root"
                    M_XCODE44_VERSION=$m_xcode_version
                fi
                ;;
            4.5*)
                m_version_compare $M_XCODE45_VERSION $m_xcode_version
                if [[ $? != 2 ]]
                then
                    M_XCODE45="$m_xcode_root"
                    M_XCODE45_VERSION=$m_xcode_version
                fi
                ;;
            *)
                m_log "skip unsupported Xcode version in '$m_xcode_root'."
                ;;
        esac
    done

    # Use most recent version of Xcode for each SDK
    if [[ -n "$M_XCODE32" ]]
    then
        m_xcode_latest="$M_XCODE32"

        M_SDK_105="$M_XCODE32/SDKs/MacOSX10.5.sdk"
        M_SDK_105_XCODE="$M_XCODE32"
        M_SDK_105_COMPILER="$M_XCODE32_COMPILER"
        m_platform_realistic_add "10.5"

        M_SDK_106="$M_XCODE32/SDKs/MacOSX10.6.sdk"
        M_SDK_106_XCODE="$M_XCODE32"
        M_SDK_106_COMPILER="$M_XCODE32_COMPILER"
        m_platform_realistic_add "10.6"

        m_platform_add "10.7"
        m_platform_add "10.8"
    fi
    if [[ -n "$M_XCODE40" ]]
    then
        m_xcode_latest="$M_XCODE40"

        M_SDK_106="$M_XCODE40/SDKs/MacOSX10.6.sdk"
        M_SDK_106_XCODE="$M_XCODE40"
        M_SDK_106_COMPILER="$M_XCODE40_COMPILER"
        m_platform_realistic_add "10.6"

        m_platform_add "10.7"
        m_platform_add "10.8"
    fi
    if [[ -n "$M_XCODE41" ]]
    then
        m_xcode_latest="$M_XCODE41"

        M_SDK_106="$M_XCODE41/SDKs/MacOSX10.6.sdk"
        M_SDK_106_XCODE="$M_XCODE41"
        M_SDK_106_COMPILER="$M_XCODE41_COMPILER"
        m_platform_realistic_add "10.6"
        m_platform_add "10.7"

        M_SDK_107="$M_XCODE41/SDKs/MacOSX10.7.sdk"
        M_SDK_107_XCODE="$M_XCODE41"
        M_SDK_107_COMPILER="$M_XCODE41_COMPILER"
        m_platform_realistic_add "10.7"

        m_platform_add "10.8"
    fi
    if [[ -n "$M_XCODE42" ]]
    then
        m_xcode_latest="$M_XCODE42"

        M_SDK_106="$M_XCODE42/SDKs/MacOSX10.6.sdk"
        M_SDK_106_XCODE="$M_XCODE42"
        M_SDK_106_COMPILER="$M_XCODE42_COMPILER"
        m_platform_realistic_add "10.6"
        m_platform_add "10.7"

        M_SDK_107="$M_XCODE42/SDKs/MacOSX10.7.sdk"
        M_SDK_107_XCODE="$M_XCODE42"
        M_SDK_107_COMPILER="$M_XCODE42_COMPILER"
        m_platform_realistic_add "10.7"

        m_platform_add "10.8"
    fi
    if [[ -n "$M_XCODE43" ]]
    then
        m_xcode_latest="$M_XCODE43"

        M_SDK_106="$M_XCODE43/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.6.sdk"
        M_SDK_106_XCODE="$M_XCODE43"
        M_SDK_106_COMPILER="$M_XCODE43_COMPILER"
        m_platform_realistic_add "10.6"
        m_platform_add "10.7"

        M_SDK_107="$M_XCODE43/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.7.sdk"
        M_SDK_107_XCODE="$M_XCODE43"
        M_SDK_107_COMPILER="$M_XCODE43_COMPILER"
        m_platform_realistic_add "10.7"

        m_platform_add "10.8"
    fi
    if [[ -n "$M_XCODE44" ]]
    then
        m_xcode_latest="$M_XCODE44"

        M_SDK_107="$M_XCODE44/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.7.sdk"
        M_SDK_107_XCODE="$M_XCODE44"
        M_SDK_107_COMPILER="$M_XCODE44_COMPILER"
        m_platform_realistic_add "10.7"
        m_platform_add "10.8"

        M_SDK_108="$M_XCODE44/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk"
        M_SDK_108_XCODE="$M_XCODE44"
        M_SDK_108_COMPILER="$M_XCODE44_COMPILER"
        m_platform_realistic_add "10.8"
    fi
    if [[ -n "$M_XCODE45" ]]
    then
        m_xcode_latest="$M_XCODE45"

        M_SDK_107="$M_XCODE45/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.7.sdk"
        M_SDK_107_XCODE="$M_XCODE45"
        M_SDK_107_COMPILER="$M_XCODE45_COMPILER"
        m_platform_realistic_add "10.7"
        m_platform_add "10.8"

        M_SDK_108="$M_XCODE45/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.8.sdk"
        M_SDK_108_XCODE="$M_XCODE45"
        M_SDK_108_COMPILER="$M_XCODE45_COMPILER"
        m_platform_realistic_add "10.8"
    fi

    m_read_input $*

    if [[ -z "$M_PLATFORMS" || -z "$m_xcode_latest" ]]
    then
        false
        m_exit_on_error "no supported version of Xcode found."
    fi

    m_log "supported platforms: $M_PLATFORMS"

    m_set_srcroot
    m_log "source root: $m_srcroot"

    m_validate_input
    m_handler
    exit $?
# }
