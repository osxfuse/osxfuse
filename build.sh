#! /bin/bash
# Copyright (C) 2008-2009 Google. All Rights Reserved.
#
# Amit Singh <singh@>
# Repurposes code from several earlier scripts by Ted Bonkenburg.
#

PATH=/Developer/usr/sbin:/Developer/usr/bin:/Developer/Tools:/Developer/Applications:/sbin:/usr/sbin:/bin:/usr/bin

export PATH

# Configurables
#
# Beware: GNU libtool cannot handle directory names containing whitespace.
#         Therefore, do not set M_CONF_TMPDIR to such a directory.
#
readonly M_CONF_TMPDIR=/tmp

if [ -n "$OSXFUSE_PRIVATE_KEY" ]; then
    readonly M_CONF_PRIVKEY="$OSXFUSE_PRIVATE_KEY"
else
    readonly M_CONF_PRIVKEY="$HOME/.osxfuse_private_key"
fi

# Other constants
#
readonly M_PROGDESC="OSXFUSE build tool"
readonly M_PROGNAME=build
readonly M_PROGVERS=1.0

readonly M_DEFAULT_VALUE=__default__

readonly M_CONFIGURATIONS="Debug Release" # default is Release
readonly M_PLATFORMS="10.5 10.6 10.7"     # default is native
readonly M_PLATFORMS_REALISTIC="10.5"
readonly M_TARGETS="clean dist examples lib reload smalldist swconfigure"
readonly M_TARGETS_WITH_PLATFORM="examples lib smalldist swconfigure"

readonly M_DEFAULT_PLATFORM="$M_DEFAULT_VALUE"
readonly M_DEFAULT_TARGET="$M_DEFAULT_VALUE"

readonly M_XCODE_VERSION_REQUIRED=4.0.0

# Globals
#
declare m_args=
declare m_active_target=""
declare m_configuration="Release"
declare m_developer=0
declare m_osname=""
declare m_platform="$M_DEFAULT_PLATFORM"
declare m_release=""
declare m_shortcircuit=0
declare m_srcroot=""
declare m_srcroot_platformdir=""
declare m_stderr=/dev/stderr
declare m_stdout=/dev/stdout
declare m_suprompt=" invalid "
declare m_target="$M_DEFAULT_TARGET"
declare m_usdk_dir=""
declare m_version_leopard=""
declare m_version_snowleopard=""
declare m_version_lion=""
declare m_xcode_version=

# Other implementation details
#
readonly M_FSBUNDLE_NAME="osxfusefs.fs"
readonly M_INSTALL_RESOURCES_DIR="Install_resources"
readonly M_KEXT_ID="com.github.osxfuse.osxfusefs"
readonly M_KEXT_NAME="osxfusefs.kext"
readonly M_KEXT_SYMBOLS="osxfusefs-symbols"
readonly M_LOGPREFIX="OSXFUSEBuildTool"
readonly M_OSXFUSE_PRODUCT_ID="com.github.osxfuse.OSXFUSE"

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
readonly M_PKGID_OSXFUSE="com.github.osxfuse.pkg.OSXFUSE"
readonly M_PKGBASENAME_OSXFUSE="OSXFUSE"
readonly M_PKGNAME_OSXFUSE="${M_PKGBASENAME_OSXFUSE}.pkg"

readonly M_WANTSU="needs the Administrator password"
readonly M_WARNING="*** Warning"

function m_help()
{
    cat <<__END_HELP_CONTENT
$M_PROGDESC version $M_PROGVERS
Copyright (C) 2008 Google. All Rights Reserved.
Usage:
  $M_PROGNAME [-dhqsv] [-c configuration] [-p platform] -t target

  * configuration is one of: $M_CONFIGURATIONS (default is $m_configuration)
  * platform is one of: $M_PLATFORMS (default is the host's platform)
  * target is one of: $M_TARGETS
  * platforms can only be specified for: $M_TARGETS_WITH_PLATFORM

The target keywords mean the following:
    clean       clean all targets
    dist        create a multiplatform distribution package
    examples    build example file systems (e.g. fusexmp_fh and hello)
    lib         build the user-space library (e.g. to run fusexmp_fh)
    reload      rebuild and reload the kernel extension
    smalldist   create a platform-specific distribution package
    swconfigure configure software (e.g. sshfs) for compilation

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
    m_set_srcroot "$m_platform"

    local mv_release=`awk '/#define[ \t]*OSXFUSE_VERSION_LITERAL/ {print $NF}' "kext/common/fuse_version.h"`
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

# m_set_srcroot([platform])
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
       m_platform=`sw_vers -productVersion | cut -d . -f 1,2`
    fi

    # XXX For now
    if [ "$m_platform" == "10.6" -o "$m_platform" == "10.7" ]
    then
        m_platform="10.5"
    fi

    case "$m_platform" in
    10.5*)
        m_osname="Leopard"
        m_usdk_dir="/Developer/SDKs/MacOSX10.5.sdk"
    ;;
    10.6*)
        m_osname="Snow Leopard"
        m_usdk_dir="/Developer/SDKs/MacOSX10.6.sdk"
    ;;
    10.7*)
        m_osname="Lion"
        m_usdk_dir="/Developer/SDKs/MacOSX10.7.sdk"
    ;;
    *)
        m_osname="Unknown"
        m_usdk_dir=""
        retval=1
    ;;
    esac

    return $retval
}

# m_build_pkg(pkgversion, install_srcroot, install_payload, pkgid, pkgname, output_dir)
#
function m_build_pkg()
{
    local bp_pkgversion="$1"
    local bp_install_srcroot="$2"
    local bp_install_payload="$3"
    local bp_pkgid="$4"
    local bp_pkgname="$5"
    local bp_output_dir="$6"

    # Make the package
    m_set_suprompt "to run packagemaker"
    if [ -d "$bp_install_srcroot/Scripts" ]
    then
        sudo -p "$m_suprompt" \
            packagemaker -r "$bp_install_payload" \
            -i "$bp_pkgid" \
            -f "$bp_install_srcroot/PackageInfo" \
            -o "$bp_output_dir/$bp_pkgname" \
            -n "$bp_pkgversion" \
            -s "$bp_install_srcroot/Scripts" \
            -g "$M_PKG_VERSION" -m -v \
            >$m_stdout 2>$m_stderr
    else
        sudo -p "$m_suprompt" \
            packagemaker -r "$bp_install_payload" \
            -i "$bp_pkgid" \
            -f "$bp_install_srcroot/PackageInfo" \
            -o "$bp_output_dir/$bp_pkgname" \
            -n "$bp_pkgversion" \
            -g "$M_PKG_VERSION" -m -v \
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

    m_set_srcroot "$m_platform"

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
    ./darwin_configure.sh "$kernel_dir" >$m_stdout 2>$m_stderr
    m_exit_on_error "cannot configure OSXFUSE library source for compilation."

    m_log "running make"
    make -j2 >$m_stdout 2>$m_stderr
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

    m_set_srcroot "$m_platform"

    local kernel_dir="$m_srcroot/kext"
    if [ ! -d "$kernel_dir" ]
    then
        false
        m_exit_on_error "cannot access directory '$kernel_dir'."
    fi

    if [ -e "$M_CONF_TMPDIR/$M_KEXT_NAME" ]
    then
        m_set_suprompt "to remove old OSXFUSE kext"
        sudo -p "$m_suprompt" rm -rf "$M_CONF_TMPDIR/$M_KEXT_NAME"
        m_exit_on_error "cannot remove old copy of OSXFUSE kext."
    fi

    if [ -e "$M_CONF_TMPDIR/$M_KEXT_SYMBOLS" ]
    then
        m_set_suprompt "to remove old copy of OSXFUSE kext symbols"
        sudo -p "$m_suprompt" rm -rf "$M_CONF_TMPDIR/$M_KEXT_SYMBOLS"
        m_exit_on_error "cannot remove old copy of OSXFUSE kext symbols."
    fi

    if [ "$1" == "clean" ]
    then
        rm -rf "$kernel_dir/build/"
        local retval=$? 
        m_log "cleaned (platform $m_platform)"
        return $retval
    fi

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

    cd "$kernel_dir"
    m_exit_on_error "failed to access the kext source directory '$kernel_dir'."

    m_log "rebuilding kext"

    xcodebuild -configuration Debug -target osxfusefs >$m_stdout 2>$m_stderr
    m_exit_on_error "xcodebuild cannot build configuration Debug for target fusefs."
 
    mkdir "$M_CONF_TMPDIR/$M_KEXT_SYMBOLS"
    m_exit_on_error "cannot create directory for OSXFUSE kext symbols."

    cp -R "$kernel_dir/build/Debug/$M_KEXT_NAME" "$M_CONF_TMPDIR/$M_KEXT_NAME"
    m_exit_on_error "cannot copy newly built OSXFUSE kext."

    m_set_suprompt "to set permissions on newly built OSXFUSE kext"
    sudo -p "$m_suprompt" chown -R root:wheel "$M_CONF_TMPDIR/$M_KEXT_NAME"
    m_exit_on_error "cannot set permissions on newly built OSXFUSE kext."

    m_log "reloading kext"

    m_set_suprompt "to load newly built OSXFUSE kext"
    sudo -p "$m_suprompt" \
        kextutil -s "$M_CONF_TMPDIR/$M_KEXT_SYMBOLS" \
            -v "$M_CONF_TMPDIR/$M_KEXT_NAME" >$m_stdout 2>$m_stderr
    m_exit_on_error "cannot load newly built OSXFUSE kext."

    echo >$m_stdout
    m_log "checking status of kernel extension"
    kextstat -l -b "$M_KEXT_ID"
    echo >$m_stdout

    echo >$m_stdout
    m_log "succeeded, results in '$M_CONF_TMPDIR'."
    echo >$m_stdout

    return 0
}

# Build examples from the user-space OSXFUSE library
#
function m_handler_examples()
{
    m_active_target="examples"

    m_set_platform

    m_set_srcroot "$m_platform"

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
    ./darwin_configure_ino64.sh "$kernel_dir" >$m_stdout 2>$m_stderr
    m_exit_on_error "cannot configure OSXFUSE library source for compilation."

    cd example
    m_exit_on_error "cannot access examples source."

    local me_installed_lib="/usr/local/lib/libosxfuse_i64.la"

    perl -pi -e "s#../lib/libosxfuse_i32.la#$me_installed_lib#g" Makefile
    m_exit_on_error "failed to prepare example source for build."

    m_log "running make"
    make -j2 >$m_stdout 2>$m_stderr
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

    if [ "$1" == "clean" ]
    then
        for m_p in $M_PLATFORMS_REALISTIC
        do
            m_platform="$m_p"
            m_handler_smalldist clean
        done

        m_active_target="dist"

        m_set_platform

        m_set_srcroot "$m_platform"

        rm -rf "$m_srcroot/prefpane/autoinstaller/build"
        m_log "cleaned internal subtarget autoinstaller"

        rm -rf "$m_srcroot/prefpane/build"
        m_log "cleaned internal subtarget prefpane"

        m_release=`awk '/#define[ \t]*OSXFUSE_VERSION_LITERAL/ {print $NF}' "$m_srcroot/kext/common/fuse_version.h" | cut -d . -f 1,2`
        if [ ! -z "$m_release" ]
        then
            if [ -e "$M_CONF_TMPDIR/osxfuse-$m_release" ]
            then
                m_set_suprompt "to remove previous output packages"
                sudo -p "$m_suprompt" rm -rf "$M_CONF_TMPDIR/osxfuse-$m_release"
                m_log "cleaned any previous output packages in '$M_CONF_TMPDIR'"
            fi
        fi

        return 0
    fi

    m_log "initiating Universal build of OSXFUSE"

    m_set_platform
    m_set_srcroot "$m_platform"

    m_log "configuration is '$m_configuration'"
    if [ "$m_developer" == "0" ]
    then
        m_log "packaging flavor is 'Mainstream'"
    else
        m_log "packaging flavor is 'Developer Prerelease'"
    fi

    m_log "locating OSXFUSE private key"
    if [ ! -f "$M_CONF_PRIVKEY" ]
    then
        false
        m_exit_on_error "cannot find OSXFUSE private key in '$M_CONF_PRIVKEY'."
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
    xcodebuild -configuration "$m_configuration" -target "Build All" \
        >$m_stdout 2>$m_stderr
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

    # Create platform-Specific OSXFUSE subpackages
    #
    for m_p in $M_PLATFORMS_REALISTIC
    do
        pushd . >/dev/null 2>/dev/null
        m_active_target="dist"
        m_platform="$m_p"
        m_log "building platform $m_platform"
        m_handler_smalldist
        popd >/dev/null 2>/dev/null
    done

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
    xcodebuild -configuration "$m_configuration" -target "OSXFUSE" \
        >$m_stdout 2>$m_stderr
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

    m_active_target="dist"

    m_release_full=`awk '/#define[ \t]*OSXFUSE_VERSION_LITERAL/ {print $NF}' "$m_srcroot/kext/common/fuse_version.h"`
    m_release=`echo "$m_release_full" | cut -d . -f 1,2`
    m_exit_on_error "cannot get OSXFUSE release version."

    local md_osxfuse_out="$M_CONF_TMPDIR/osxfuse-$m_release"
    local md_osxfuse_root="$md_osxfuse_out/pkgroot/"

    if [ -e "$md_osxfuse_out" ]
    then
        m_set_suprompt "to remove a previously built container package"
        sudo -p "$m_suprompt" rm -rf "$md_osxfuse_out"
        # ignore any errors
    fi

    m_log "initiating distribution build"

    local md_platforms=""
    local md_platform_dirs=`ls -d "$M_CONF_TMPDIR"/osxfuse-core-*${m_release}.* | paste -s -`
    m_log "found payloads $md_platform_dirs"
    for i in $md_platform_dirs
    do
        local md_tmp_versions=${i#*core-}
        local md_tmp_release_version=${md_tmp_versions#*-}
        local md_tmp_os_version=${md_tmp_versions%-*}

        md_platforms="${md_platforms},${md_tmp_os_version}=${i}/$M_PKGNAME_CORE"
        md_platforms="${md_platforms},${md_tmp_os_version}=${i}/$M_PKGNAME_MACFUSE"

        case "$md_tmp_os_version" in
        10.5)
            m_version_leopard=$md_tmp_release_version
        ;;
        10.6)
            m_version_snowleopard=$md_tmp_release_version
        ;;
        10.7)
            m_version_lion=$md_tmp_release_version
        ;;
        esac

        m_log "adding [ '$md_tmp_os_version', '$md_tmp_release_version' ]"
    done

    m_log "building '$M_PKGNAME_OSXFUSE'"

    mkdir "$md_osxfuse_out"
    m_exit_on_error "cannot create directory '$md_osxfuse_out'."

    mkdir "$md_osxfuse_root"
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

    m_build_pkg "$m_release_full" "$m_srcroot/packaging/installer/$M_PKGBASENAME_PREFPANE" "$md_osxfuse_root" "$M_PKGID_PREFPANE" "$M_PKGNAME_PREFPANE" "$md_osxfuse_out"
    m_exit_on_error "cannot create '$M_PKGNAME_PREFPANE'."

    # Build OSXFUSE installer package
    #
    cp -R "$m_srcroot/packaging/installer/$M_PKGBASENAME_OSXFUSE" "$md_osxfuse_out/OSXFUSE"
    m_exit_on_error "cannot copy the packaging files for package '$M_PKGNAME_OSXFUSE'."

    OLD_IFS="$IFS"
    IFS=","
    for i in $md_platforms
    do
        if [ x"$i" == x"" ]
        then
            continue;  # Skip empty/bogus comma-item
        fi

        local md_tmp_os_version=${i%%=*}
        local md_tmp_core_pkg=${i##*=}
        local md_tmp_core_pkg_dir=$(dirname "$md_tmp_core_pkg")
        local md_tmp_core_pkg_name=$(basename "$md_tmp_core_pkg")
        local md_tmp_pkg_dst="$md_osxfuse_out/OSXFUSE/$md_tmp_core_pkg_name"

        pkgutil --expand "$md_tmp_core_pkg" "$md_tmp_pkg_dst"
        m_exit_on_error "cannot expand flat package '$md_tmp_core_pkg_name'."
    done
    IFS="$OLD_IFS"

    pkgutil --expand "$md_osxfuse_out/$M_PKGNAME_PREFPANE" "$md_osxfuse_out/OSXFUSE/$M_PKGNAME_PREFPANE"
    m_exit_on_error "cannot expand flat package '$M_PKGNAME_PREFPANE'."

    find "$md_osxfuse_out/OSXFUSE" -name ".DS_Store" -exec rm -f '{}' \;
    m_exit_on_error "cannot remove '.DS_Store' files from package '$M_PKGNAME_OSXFUSE'."

    local md_pkg_core_size=`grep -Po 'installKBytes="\K\d+?(?=")' "$md_osxfuse_out/OSXFUSE/$M_PKGNAME_CORE/PackageInfo"`
    local md_pkg_prefpane_size=`grep -Po 'installKBytes="\K\d+?(?=")' "$md_osxfuse_out/OSXFUSE/$M_PKGNAME_PREFPANE/PackageInfo"`
    local md_pkg_macfuse_size=`grep -Po 'installKBytes="\K\d+?(?=")' "$md_osxfuse_out/OSXFUSE/$M_PKGNAME_MACFUSE/PackageInfo"`

    local md_distribution_in="$md_osxfuse_out/OSXFUSE/Distribution.in"
    local md_distribution_out="$md_osxfuse_out/OSXFUSE/Distribution"
    sed -e "s/@PKG_CORE_ID@/$M_PKGID_CORE/g" \
        -e "s/@PKG_CORE_SIZE@/$md_pkg_core_size/g" \
        -e "s/@PKG_CORE_VERSION@/$m_release_full/g" \
        -e "s/@PKG_CORE_NAME@/$M_PKGNAME_CORE/g" \
        -e "s/@PKG_PREFPANE_ID@/$M_PKGID_PREFPANE/g" \
        -e "s/@PKG_PREFPANE_SIZE@/$md_pkg_prefpane_size/g" \
        -e "s/@PKG_PREFPANE_VERSION@/$m_release_full/g" \
        -e "s/@PKG_PREFPANE_NAME@/$M_PKGNAME_PREFPANE/g" \
        -e "s/@PKG_MACFUSE_ID@/$M_PKGID_MACFUSE/g" \
        -e "s/@PKG_MACFUSE_SIZE@/$md_pkg_macfuse_size/g" \
        -e "s/@PKG_MACFUSE_VERSION@/$m_release_full/g" \
        -e "s/@PKG_MACFUSE_NAME@/$M_PKGNAME_MACFUSE/g" \
        < "$md_distribution_in" > "$md_distribution_out"
    m_exit_on_error "cannot finalize Distribution for package '$M_PKGNAME_OSXFUSE'."

    rm -f "$md_distribution_in"
    m_exit_on_error "cannot remove Distribution.in for package '$M_PKGNAME_OSXFUSE'."

    m_log "flatten installer package '$M_PKGNAME_OSXFUSE'"

    pkgutil --flatten "$md_osxfuse_out/OSXFUSE" "$md_osxfuse_out/$M_PKGNAME_OSXFUSE"
    m_exit_on_error "cannot flatten package '$M_PKGNAME_OSXFUSE'."

    # Create the distribution volume
    #
    local md_volume_name="FUSE for OS X"
    local md_scratch_dmg="$md_osxfuse_out/osxfuse-scratch.dmg"
    hdiutil create -layout NONE -size 10m -fs HFS+ -fsargs "-c c=64,a=16,e=16" \
        -volname "$md_volume_name" "$md_scratch_dmg" >$m_stdout 2>$m_stderr
    m_exit_on_error "cannot create scratch OSXFUSE disk image."

    # Attach/mount the volume
    #
    hdiutil attach -private -nobrowse "$md_scratch_dmg" >$m_stdout 2>$m_stderr
    m_exit_on_error "cannot attach scratch OSXFUSE disk image."

    local md_volume_path="/Volumes/$md_volume_name"

    # Copy over the license file
    #
    cp "$m_srcroot/License.rtf" "$md_volume_path"
    if [ $? -ne 0 ]
    then
        hdiutil detach "$md_volume_path" >$m_stdout 2>$m_stderr
        false
        m_exit_on_error "cannot copy OSXFUSE license to scratch disk image."
    fi

    /Developer/Tools/SetFile -a E "$md_volume_path/License.rtf"
    if [ $? -ne 0 ]
    then
        hdiutil detach "$md_volume_path" >$m_stdout 2>$m_stderr
        false
        m_exit_on_error "cannot hide extension of 'License.rtf'."
    fi

    # Copy over the package
    #
    local md_pkgname_installer="Install OSXFUSE $m_release.pkg"
    cp -pRX "$md_osxfuse_out/$M_PKGNAME_OSXFUSE" "$md_volume_path/$md_pkgname_installer"
    if [ $? -ne 0 ]
    then
        hdiutil detach "$md_volume_path" >$m_stdout 2>$m_stderr
        false
        m_exit_on_error "cannot copy '$M_PKGNAME_OSXFUSE' to scratch disk image."
    fi

    /Developer/Tools/SetFile -a E "$md_volume_path/$md_pkgname_installer"
    if [ $? -ne 0 ]
    then
        hdiutil detach "$md_volume_path" >$m_stdout 2>$m_stderr
        false
        m_exit_on_error "cannot hide extension of installer package."
    fi

    # Copy over the website link
    #
    cp "$m_srcroot/packaging/diskimage/OSXFUSE Website.webloc" "$md_volume_path"
    if [ $? -ne 0 ]
    then
        hdiutil detach "$md_volume_path" >$m_stdout 2>$m_stderr
        false
        m_exit_on_error "cannot copy website link to scratch disk image."
    fi

    /Developer/Tools/SetFile -a E "$md_volume_path/OSXFUSE Website.webloc"
    if [ $? -ne 0 ]
    then
        hdiutil detach "$md_volume_path" >$m_stdout 2>$m_stderr
        false
        m_exit_on_error "cannot hide extension of 'OXSFUSE Website.webloc'."
    fi

    # Create the .engine_install file
    #
    local md_engine_install="$md_volume_path/.engine_install"
    cat > "$md_engine_install" <<__END_ENGINE_INSTALL
#!/bin/sh -p
/usr/sbin/installer -pkg "\$1/$md_pkgname_installer" -target /
__END_ENGINE_INSTALL

    chmod +x "$md_engine_install"
    m_exit_on_error "cannot set permissions on autoinstaller engine file."


    # Set the custom icon
    #
    cp -pRX "$m_srcroot/packaging/images/osxfuse.icns" \
        "$md_volume_path/.VolumeIcon.icns"
    if [ $? -ne 0 ]
    then
        hdiutil detach "$md_volume_path" >$m_stdout 2>$m_stderr
        false
        m_exit_on_error "cannot copy custom volume icon to scratch disk image."
    fi

    /Developer/Tools/SetFile -a C "$md_volume_path"
    if [ $? -ne 0 ]
    then
        hdiutil detach "$md_volume_path" >$m_stdout 2>$m_stderr
        false
        m_exit_on_error "cannot set custom volume icon on scratch disk image."
    fi

    # Set custom background
    #
    mkdir "$md_volume_path/.background"
    if [ $? -ne 0 ]
    then
        hdiutil detach "$md_volume_path" >$m_stdout 2>$m_stderr
        false
        m_exit_on_error "cannot make directory '.background' on scratch disk image."
    fi

    cp "$m_srcroot/packaging/diskimage/background.png" "$md_volume_path/.background/"
    if [ $? -ne 0 ]
    then
        hdiutil detach "$md_volume_path" >$m_stdout 2>$m_stderr
        false
        m_exit_on_error "cannot copy background picture to scratch disk image."
    fi

    # Customize scratch image
    #
    echo '
        tell application "Finder"
            tell disk "'$md_volume_name'"
                open
                set current view of container window to icon view
                set toolbar visible of container window to false
                set statusbar visible of container window to false
                set the bounds of container window to {0, 0, 500, 350}
                set theViewOptions to the icon view options of container window
                set arrangement of theViewOptions to not arranged
                set icon size of theViewOptions to 128
                set background picture of theViewOptions to file ".background:background.png"
                set position of item "License.rtf" of container window to {100, 230}
                set position of item "'$md_pkgname_installer'" of container window to {250, 230}
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
        hdiutil detach "$md_volume_path" >$m_stdout 2>$m_stderr
        false
        m_exit_on_error "cannot customize the scratch disk image."
    fi

    chmod -Rf go-w "$md_volume_path"
    sync
    sync
    # ignore errors

    # Detach the volume.
    hdiutil detach "$md_volume_path" >$m_stdout 2>$m_stderr
    if [ $? -ne 0 ]
    then
        false
        m_exit_on_error "cannot detach volume '$md_volume_path'."
    fi

    # Convert to a read-only compressed dmg
    #
    local md_dmg_name="OSXFUSE-$m_release.dmg"
    local md_dmg_path="$md_osxfuse_out/$md_dmg_name"
    hdiutil convert -imagekey zlib-level=9 -format UDZO "$md_scratch_dmg" \
        -o "$md_dmg_path" >$m_stdout 2>$m_stderr
    m_exit_on_error "cannot finalize OSXFUSE distribution disk image."

    rm -f "$md_scratch_dmg"
    # ignore any errors

    m_log "creating autoinstaller rules"

    # Make autoinstaller rules file
    #
    local md_dmg_hash=$(openssl sha1 -binary "$md_dmg_path" | openssl base64)
    local md_dmg_size=$(stat -f%z "$md_dmg_path")

    local md_rules_plist="$md_osxfuse_out/DeveloperRelease.plist"
    local md_download_url="http://osxfuse.github.com/releases/developer/$md_dmg_name"
    if [ "$m_developer" == "0" ]
    then
        md_rules_plist="$md_osxfuse_out/CurrentRelease.plist"
        md_download_url="http://osxfuse.github.com/releases/$md_dmg_name"
    fi

cat > "$md_rules_plist" <<__END_RULES_PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Rules</key>
  <array>
    <dict>
      <key>ProductID</key>
      <string>$M_OSXFUSE_PRODUCT_ID</string>
      <key>Predicate</key>
      <string>SystemVersion.ProductVersion beginswith "10.7" AND Ticket.version != "$m_version_leopard"</string>
      <key>Version</key>
      <string>$m_version_leopard</string>
      <key>Codebase</key>
      <string>$md_download_url</string>
      <key>Hash</key>
      <string>$md_dmg_hash</string>
      <key>Size</key>
      <string>$md_dmg_size</string>
    </dict>
    <dict>
      <key>ProductID</key>
      <string>$M_OSXFUSE_PRODUCT_ID</string>
      <key>Predicate</key>
      <string>SystemVersion.ProductVersion beginswith "10.6" AND Ticket.version != "$m_version_leopard"</string>
      <key>Version</key>
      <string>$m_version_leopard</string>
      <key>Codebase</key>
      <string>$md_download_url</string>
      <key>Hash</key>
      <string>$md_dmg_hash</string>
      <key>Size</key>
      <string>$md_dmg_size</string>
    </dict>
    <dict>
      <key>ProductID</key>
      <string>$M_OSXFUSE_PRODUCT_ID</string>
      <key>Predicate</key>
      <string>SystemVersion.ProductVersion beginswith "10.5" AND Ticket.version != "$m_version_leopard"</string>
      <key>Version</key>
      <string>$m_version_leopard</string>
      <key>Codebase</key>
      <string>$md_download_url</string>
      <key>Hash</key>
      <string>$md_dmg_hash</string>
      <key>Size</key>
      <string>$md_dmg_size</string>
    </dict>
  </array>
</dict>
</plist>
__END_RULES_PLIST

    # Sign the output rules
    #
  
    m_log "signing autoinstaller rules"

    m_set_suprompt "to sign the rules file"
    sudo -p "$m_suprompt" \
        "$md_plistsigner" --sign --key "$M_CONF_PRIVKEY" \
            "$md_rules_plist" >$m_stdout 2>$m_stderr
    m_exit_on_error "cannot sign the rules file '$md_rules_plist' with key '$M_CONF_PRIVKEY'."

    echo >$m_stdout
    m_log "succeeded, results in '$md_osxfuse_out'."
    echo >$m_stdout

    return 0
}


# Build a platform-specific distribution package
#
function m_handler_smalldist()
{
    m_active_target="smalldist"

    m_set_platform

    m_set_srcroot "$m_platform"

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

    if [ "$m_shortcircuit" != "1" ]
    then
        rm -rf "$lib_dir/build/"
        rm -rf "$kernel_dir/build/"
        rm -rf "$m_srcroot/sdk/build/"
    fi

    local ms_os_version="$m_platform"
    local ms_osxfuse_version=`awk '/#define[ \t]*OSXFUSE_VERSION_LITERAL/ {print $NF}' "$kernel_dir"/common/fuse_version.h`
    m_exit_on_error "cannot get platform-specific OSXFUSE version."

    local ms_osxfuse_out="$M_CONF_TMPDIR/osxfuse-core-$ms_os_version-$ms_osxfuse_version"
    local ms_osxfuse_build="$ms_osxfuse_out/build/"
    local ms_osxfuse_root="$ms_osxfuse_out/osxfuse/"
    local ms_macfuse_root="$ms_osxfuse_out/macfuse/"

    if [ "$m_shortcircuit" != "1" ]
    then
        if [ -e "$ms_osxfuse_out" ]
        then
            m_set_suprompt "to remove a previously built platform-specific package"
            sudo -p "$m_suprompt" rm -rf "$ms_osxfuse_out"
            m_exit_on_error "failed to clean up previous platform-specific OSXFUSE build."
        fi
        if [ -e "$M_CONF_TMPDIR/osxfuse-core-$ms_os_version-"* ]
        then
            m_warn "removing unrecognized version of platform-specific package"
            m_set_suprompt "to remove unrecognized version of platform-specific package"
            sudo -p "$m_suprompt" rm -rf "$M_CONF_TMPDIR/osxfuse-core-$ms_os_version-"*
            m_exit_on_error "failed to clean up unrecognized version of platform-specific package."
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
        local retval=$?
        m_log "cleaned (platform $m_platform)"
        return $retval
    fi

    m_log "initiating Universal build for $m_platform"

    cd "$kernel_dir"
    m_exit_on_error "failed to access the kext source directory '$kernel_dir'."

    m_log "building OSXFUSE kernel extension and tools"

    if [ "$m_developer" == "0" ]
    then
        xcodebuild -configuration "$m_configuration" -target All >$m_stdout 2>$m_stderr
    else
        xcodebuild OSXFUSE_BUILD_FLAVOR=Beta -configuration "$m_configuration" -target All >$m_stdout 2>$m_stderr
    fi

    m_exit_on_error "xcodebuild cannot build configuration $m_configuration."

    # Go for it

    local ms_project_dir="$kernel_dir"

    local ms_built_products_dir="$kernel_dir/build/$m_configuration/"
    if [ ! -d "$ms_built_products_dir" ]
    then
        m_exit_on_error "cannot find built products directory."
    fi

    ms_osxfuse_system_dir=""

    mkdir -p "$ms_osxfuse_build"
    m_exit_on_error "cannot make new build directory '$ms_osxfuse_build'."

    mkdir -p "$ms_osxfuse_root"
    m_exit_on_error "cannot make directory '$ms_osxfuse_root'."

    mkdir -p "$ms_osxfuse_root$ms_osxfuse_system_dir/Library/Filesystems/"
    m_exit_on_error "cannot make directory '$ms_osxfuse_root$ms_osxfuse_system_dir/Library/Filesystems/'."

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
    local ms_bundle_dir="$ms_osxfuse_root$ms_osxfuse_system_dir/$ms_bundle_dir_generic"
    local ms_bundle_support_dir="$ms_bundle_dir/Support"

    cp -pRX "$ms_built_products_dir/$M_FSBUNDLE_NAME" "$ms_bundle_dir"
    m_exit_on_error "cannot copy '$M_FSBUNDLE_NAME' to destination."

    mkdir -p "$ms_bundle_support_dir"
    m_exit_on_error "cannot make directory '$ms_bundle_support_dir'."

    cp -pRX "$ms_built_products_dir/$M_KEXT_NAME" "$ms_bundle_support_dir/$M_KEXT_NAME"
    m_exit_on_error "cannot copy '$M_KEXT_NAME' to destination."

    cp -pRX "$ms_built_products_dir/load_osxfusefs" "$ms_bundle_support_dir/load_osxfusefs"
    m_exit_on_error "cannot copy 'load_osxfusefs' to destination."

    cp -pRX "$ms_built_products_dir/mount_osxfusefs" "$ms_bundle_support_dir/mount_osxfusefs"
    m_exit_on_error "cannot copy 'mount_osxfusefs' to destination."

    cp -pRX "$m_srcroot/packaging/uninstaller/uninstall-osxfuse-core.sh" "$ms_bundle_support_dir/uninstall-osxfuse-core.sh"
    m_exit_on_error "cannot copy 'uninstall-osxfuse-core.sh' to destination."

    cp -pRX "$m_srcroot/packaging/uninstaller/uninstall-macfuse-core.sh" "$ms_bundle_support_dir/uninstall-macfuse-core.sh"
    m_exit_on_error "cannot copy 'uninstall-macfuse-core.sh' to destination."

    ln -s "/Library/PreferencePanes/OSXFUSE.prefPane/Contents/MacOS/autoinstall-osxfuse-core" "$ms_bundle_support_dir/autoinstall-osxfuse-core"
    m_exit_on_error "cannot create legacy symlink '$ms_bundle_support_dir/autoinstall-osxfuse-core'".

    # Build the user-space OSXFUSE library
    #

    m_log "building user-space OSXFUSE library"

    cp -pRX "$lib_dir" "$ms_osxfuse_build"
    m_exit_on_error "cannot copy OSXFUSE library source from '$lib_dir'."

    cd "$ms_osxfuse_build"/fuse
    m_exit_on_error "cannot access OSXFUSE library source in '$ms_osxfuse_build/fuse'."

    ./darwin_configure.sh "$kernel_dir" >$m_stdout 2>$m_stderr
    m_exit_on_error "cannot configure OSXFUSE library source for compilation."

    make -j2 >$m_stdout 2>$m_stderr
    m_exit_on_error "make failed while compiling the OSXFUSE library."

    make install DESTDIR="$ms_osxfuse_root" >$m_stdout 2>$m_stderr
    m_exit_on_error "cannot prepare library build for installation."

    rm -f "ms_osxfuse_root"/usr/local/lib/*ulockmgr*
    # ignore any errors

    rm -f "ms_osxfuse_root"/usr/local/include/*ulockmgr*
    # ignore any errors

    # Now build again, if necessary, with 64-bit inode support
    #

    m_log "building user-space OSXFUSE library (ino64)"

    cd "$ms_osxfuse_build"/fuse/lib
    m_exit_on_error "cannot access OSXFUSE library (ino64) source in '$ms_osxfuse_build/fuse/lib'."

    make clean >$m_stdout 2>$m_stderr
    m_exit_on_error "make failed while compiling the OSXFUSE library (ino64)."

    perl -pi -e 's#libosxfuse_i32#libosxfuse_i64#g' Makefile
    m_exit_on_error "failed to prepare OSXFUSE library (ino64) for compilation."

    perl -pi -e 's#-D__DARWIN_64_BIT_INO_T=0#-D__DARWIN_64_BIT_INO_T=1#g' Makefile
    m_exit_on_error "failed to prepare OSXFUSE library (ino64) for compilation."

    make -j2 >$m_stdout 2>$m_stderr
    m_exit_on_error "make failed while compiling the OSXFUSE library (ino64)."

    make install DESTDIR="$ms_osxfuse_root" >$m_stdout 2>$m_stderr
    m_exit_on_error "cannot prepare OSXFUSE library (ino64) build for installation."

    rm -f "$ms_osxfuse_root"/usr/local/lib/*ulockmgr*
    # ignore any errors

    rm -f "$ms_osxfuse_root"/usr/local/include/*ulockmgr*
    # ignore any errors

    for f in "$ms_osxfuse_root"/usr/local/lib/libosxfuse_i64*.dylib; do
        local source=`basename "$f"`
        local target="`echo \"$f\" | sed 's/libosxfuse_i64/libosxfuse/'`"
        ln -s "$source" "$target"
        m_exit_on_error "cannot create symlink '$target' -> '$source'."
    done
    ln -s libosxfuse_i64.la "$ms_osxfuse_root/usr/local/lib/libosxfuse.la"
    m_exit_on_error "cannot create symlink '$ms_osxfuse_root/usr/local/lib/libosxfuse.la' -> 'libosxfuse_i64.la'."

    ln -s osxfuse.pc "$ms_osxfuse_root/usr/local/lib/pkgconfig/fuse.pc"
    m_exit_on_error "cannot create symlink '$ms_osxfuse_root/usr/local/lib/pkgconfig/fuse.pc' -> 'osxfuse.pc'."

    # generate dsym
    dsymutil "$ms_osxfuse_root"/usr/local/lib/libosxfuse_i32.dylib
    m_exit_on_error "cannot generate debugging information for libosxfuse_i32."
    dsymutil "$ms_osxfuse_root"/usr/local/lib/libosxfuse_i64.dylib
    m_exit_on_error "cannot generate debugging information for libosxfuse_i64."

    # Build MacFUSE compatibility layer for user-space OSXFUSE library
    #

    m_log "building MacFUSE compatibility layer for user-space OSXFUSE library"

    cd "$lib_dir"
    m_exit_on_error "cannot access compatibility layer directory."

    xcodebuild -target macfuse -configuration "$m_configuration" OSXFUSE_BUILD_ROOT="$ms_osxfuse_root" >$m_stdout 2>$m_stderr
    m_exit_on_error "xcodebuild cannot build configuration '$m_configuration'."

    cp -pRX build/"$m_configuration"/libmacfuse*.dylib "$ms_macfuse_root/usr/local/lib/"
    m_exit_on_error "cannot copy 'libmacfuse*.dylib' to destination."

    for f in "$ms_macfuse_root"/usr/local/lib/libmacfuse_i32*.dylib; do
        local source=`basename "$f"`
        local target="`echo \"$f\" | sed 's/libmacfuse_i32/libfuse/'`"
        ln -s "$source" "$target"
        m_exit_on_error "cannot create symlink '$target' -> '$source'."
    done

    for f in "$ms_macfuse_root"/usr/local/lib/libmacfuse_i64*.dylib; do
        local source=`basename "$f"`
        local target="`echo \"$f\" | sed 's/libmacfuse_i64/libfuse_ino64/'`"
        ln -s "$source" "$target"
        m_exit_on_error "cannot create symlink '$target' -> '$source'."
    done

    ln -s libmacfuse_i32.dylib "$ms_macfuse_root/usr/local/lib/libfuse.0.dylib"
    m_exit_on_error "cannot create compatibility symlink 'libfuse.0.dylib'."

    # Build OSXFUSE.framework
    #

    m_log "building OSXFUSE Objective-C SDK"

    cd "$ms_project_dir/../sdk"
    m_exit_on_error "cannot access Objective-C SDK directory."

    rm -rf build/
    m_exit_on_error "cannot remove previous build of OSXFUSE.framework."

    xcodebuild -configuration "$m_configuration" -target "OSXFUSE-$ms_os_version" OSXFUSE_BUILD_ROOT="$ms_osxfuse_root" OSXFUSE_BUNDLE_VERSION_LITERAL="$ms_osxfuse_version" >$m_stdout 2>$m_stderr
    m_exit_on_error "xcodebuild cannot build configuration '$m_configuration'."

    cp -pRX build/"$m_configuration"/*.framework "$ms_osxfuse_root/Library/Frameworks/"
    m_exit_on_error "cannot copy 'OSXFUSE.framework' to destination."

    mv "$ms_osxfuse_root"/usr/local/lib/*.dSYM "$ms_osxfuse_root"/Library/Frameworks/OSXFUSE.framework/Resources/Debug/
#   mkdir -p "$ms_osxfuse_root/Library/Application Support/Developer/Shared/Xcode/Project Templates"
#   m_exit_on_error "cannot create directory for Xcode templates."
#   ln -s "/Library/Frameworks/OSXFUSE.framework/Resources/ProjectTemplates/" "$ms_osxfuse_root/Library/Application Support/Developer/Shared/Xcode/Project Templates/OSXFUSE"
#   m_exit_on_error "cannot create symlink for Xcode templates."

    # Link MacFUSE.framework back to OSXFUSE.framework
    #

    mkdir -p "$ms_macfuse_root/Library/Frameworks/MacFUSE.framework/Versions/A"
    m_exit_on_error "cannot create directory structure of 'MacFUSE.framework'."
    ln -s "/Library/Frameworks/OSXFUSE.framework/Versions/A/OSXFUSE" "$ms_macfuse_root/Library/Frameworks/MacFUSE.framework/Versions/A/MacFUSE"
    m_exit_on_error "cannot create symlink for 'MacFUSE.framework'."

    m_set_suprompt "to chown '$ms_osxfuse_root/*'"
    sudo -p "$m_suprompt" chown -R root:wheel "$ms_osxfuse_root"/*
    m_exit_on_error "cannot chown '$ms_osxfuse_root/*'."

    m_set_suprompt "to chown '$ms_macfuse_root/*'"
    sudo -p "$m_suprompt" chown -R root:wheel "$ms_macfuse_root"/*
    m_exit_on_error "cannot chown '$ms_macfuse_root/*'."

    m_set_suprompt "to setuid 'load_osxfusefs'"
    sudo -p "$m_suprompt" chmod u+s "$ms_bundle_support_dir/load_osxfusefs"
    m_exit_on_error "cannot setuid 'load_osxfusefs'."

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
        chmod -h 755 `find "$ms_osxfuse_root/usr/local/lib" -type l`
    m_exit_on_error "cannot chmod files in '$ms_osxfuse_root/usr/local/lib/'."

    m_set_suprompt "to chmod files in '$ms_macfuse_root/usr/local/lib/'"
    sudo -p "$m_suprompt" \
    chmod -h 755 `find "$ms_macfuse_root/usr/local/lib" -type l`
    m_exit_on_error "cannot chmod files in '$ms_macfuse_root/usr/local/lib/'."

    m_set_suprompt "to chmod files in '$ms_osxfuse_root/Library/Frameworks/'"
    sudo -p "$m_suprompt" \
        chmod -h 755 `find "$ms_osxfuse_root/Library/Frameworks/" -type l`
    # no exit upon error

    m_set_suprompt "to chmod files in '$ms_macfuse_root/Library/Frameworks/'"
    sudo -p "$m_suprompt" \
    chmod -h 755 `find "$ms_macfuse_root/Library/Frameworks/" -type l`
    # no exit upon error

    cd "$ms_osxfuse_root"
    m_exit_on_error "cannot access directory '$ms_osxfuse_root'."

    cd "$ms_macfuse_root"
    m_exit_on_error "cannot access directory '$ms_macfuse_root'."

    # Create the OSXFUSE Installer Package
    #

    m_log "building installer package for $m_platform"

    m_build_pkg "$ms_osxfuse_version" "$m_srcroot/packaging/installer/$M_PKGBASENAME_CORE" "$ms_osxfuse_root" "$M_PKGID_CORE" "$M_PKGNAME_CORE" "$ms_osxfuse_out"
    m_exit_on_error "cannot create '$M_PKGNAME_CORE'."

    m_build_pkg "$ms_osxfuse_version" "$m_srcroot/packaging/installer/$M_PKGBASENAME_MACFUSE" "$ms_macfuse_root" "$M_PKGID_MACFUSE" "$M_PKGNAME_MACFUSE" "$ms_osxfuse_out"
    m_exit_on_error "cannot create '$M_PKGNAME_MACFUSE'."

    echo >$m_stdout
    m_log "succeeded, results in '$ms_osxfuse_out'."
    echo >$m_stdout

    return 0
}

function m_handler_swconfigure()
{
    m_active_target="swconfigure"

    m_set_platform

    m_set_srcroot "$m_platform"

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

    local current_dir=`pwd`
    local current_product=`basename "$current_dir"`

    local extra_cflags=""
    local architectures=""

    architectures="-arch i386 -arch x86_64"

    local common_cflags="-O0 -g $architectures -isysroot $m_usdk_dir -I/usr/local/include"
    local common_ldflags="-Wl,-syslibroot,$m_usdk_dir $architectures -L/usr/local/lib"

    local final_cflags="$common_cflags $extra_cflags"
    local final_ldflags="$common_ldflags"

    local retval=1

    # For pkg-config and such
    PATH=$PATH:/usr/local/sbin:/usr/local/bin
    export PATH

    # We have some special cases for current_product

    case "$current_product" in

    gettext*)
        m_log "Configuring Universal build of gettext for Mac OS X \"$m_osname\""
        CFLAGS="$final_cflags -D_POSIX_C_SOURCE=200112L" LDFLAGS="$final_ldflags -fno-common" ./configure --prefix=/usr/local --disable-dependency-tracking --with-libiconv-prefix="$m_usdk_dir"/usr
        retval=$?
        ;; 

    glib*)
        m_log "Configuring Universal build of glib for Mac OS X \"$m_osname\""
        CFLAGS="$final_cflags" LDFLAGS="$final_ldflags" ./configure --prefix=/usr/local --disable-dependency-tracking --enable-static
        retval=$?
        ;;

    pkg-config*)
        m_log "Configuring Universal build of pkg-config for Mac OS X \"$m_osname\""
        CFLAGS="$final_cflags" LDFLAGS="$final_ldflags" ./configure --prefix=/usr/local --disable-dependency-tracking
        ;;

    *sshfs*)
        m_log "Configuring Universal build of sshfs for Mac OS X \"$m_osname\""
        CFLAGS="$final_cflags -D__FreeBSD__=10 -DDARWIN_SEMAPHORE_COMPAT -DSSH_NODELAY_WORKAROUND" LDFLAGS="$final_ldflags" ./configure --prefix=/usr/local --disable-dependency-tracking
        ;;

    *)
        m_log "Configuring Universal build of generic software for Mac OS X \"$m_osname\""
        CFLAGS="$final_cflags" LDFLAGS="$final_ldflags" ./configure --prefix=/usr/local --disable-dependency-tracking
        ;;

    esac

    return $retval
}

# --

function m_validate_xcode()
{
    m_xcode_version=`xcodebuild -version | head -1 | grep Xcode | awk '{print $NF}'`
    if [ $? != 0 ] || [ -z "$m_xcode_version" ]
    then
        echo "failed to determine Xcode version."
        exit 2
    fi

    local mvs_xcode_major=`echo $m_xcode_version | cut -d . -f 1`
    local mvs_xcode_minor=`echo $m_xcode_version | cut -d . -f 2`
    if [ -z $mvs_xcode_minor ]
    then
        mvs_xcode_minor=0
    fi
    local mvs_xcode_rev=`echo $m_xcode_version | cut -d . -f 3`
    if [ -z $mvs_xcode_rev ]
    then
        mvs_xcode_rev=0
    fi
    local mvs_have=$(( $mvs_xcode_major * 100 + $mvs_xcode_minor * 10 + $mvs_xcode_rev ))

    mvs_xcode_major=`echo $M_XCODE_VERSION_REQUIRED | cut -d . -f 1`
    mvs_xcode_minor=`echo $M_XCODE_VERSION_REQUIRED | cut -d . -f 2`
    if [ -z $mvs_xcode_minor ]
    then
        mvs_xcode_minor=0
    fi
    mvs_xcode_rev=`echo $M_XCODE_VERSION_REQUIRED | cut -d . -f 3`
    if [ -z $mvs_xcode_rev ]
    then
        mvs_xcode_rev=0
    fi
    local mvs_want=$(( $mvs_xcode_major * 100 + $mvs_xcode_minor * 10 + $mvs_xcode_rev ))

    if [ $mvs_have -lt $mvs_want ]
    then
        echo "Xcode version $M_XCODE_VERSION_REQUIRED or higher is required to build OSXFUSE."
        exit 2
    fi 

    m_active_target="preflight"
    m_log "Xcode version $m_xcode_version found (minimum requirement is $M_XCODE_VERSION_REQUIRED)"

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
        --)
            shift
            break
            ;;
        esac
    done
}

function m_handler()
{
    case "$m_target" in

    "clean")
        m_handler_examples clean
        m_handler_lib clean
        m_handler_reload clean
        m_handler_dist clean
    ;;

    "dist")
        m_validate_xcode
        m_handler_dist
    ;;

    "examples")
        m_handler_examples
    ;;

    "lib")
        m_handler_lib
    ;;

    "reload")
        m_validate_xcode
        m_handler_reload
    ;;

    "smalldist")
        m_validate_xcode
        m_handler_smalldist
    ;;

    "swconfigure")
        m_handler_swconfigure
    ;;

    *)
        echo "Try $0 -h for help."
    ;;

    esac
}

# main()
# {
    m_read_input $*
    m_validate_input
    m_handler
    exit $?
# }
