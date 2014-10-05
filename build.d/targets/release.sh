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


declare -ra BUILD_TARGET_ACTIONS=("build" "clean")

declare     BUILD_TARGET_OPTION_CODE_SIGN_IDENTITY="Developer ID Application"
declare     BUILD_TARGET_OPTION_PRODUCT_SIGN_IDENTITY="Developer ID Installer"

declare -r  RELEASE_RULES_PLIST_PRIVATE_KEY_PATH="${HOME}/.osxfuse_private_key"


function release_build
{
    build_target_getopt -p meta -- "${@}"

    common_log "Clean target"
    build_target_invoke "${BUILD_TARGET_NAME}" clean
    common_die_on_error "Failed to clean target"

    common_log "Build target"

    local osxfuse_version=""
    osxfuse_version="`osxfuse_get_version`"
    common_die_on_error "Failed to determine osxfuse version number"

    local debug_directory="${BUILD_TARGET_BUILD_DIRECTORY}/osxfuse-${osxfuse_version}-debug"

    /bin/mkdir -p "${BUILD_TARGET_BUILD_DIRECTORY}" 1>&3 2>&4
    common_die_on_error "Failed to create build directory"

    /bin/mkdir -p "${debug_directory}" 1>&3 2>&4
    common_die_on_error "Failed to create debug directory"

    # Build distribution package

    build_target_invoke distribution build -s 10.5 -d 10.5 -c Release \
                                           --kext=10.5 --kext=10.6 --kext="10.7->10.6" --kext="10.8->10.6" --kext=10.9 --kext="10.10->10.9" \
                                           --macfuse \
                                           --code-sign-identity="${BUILD_TARGET_OPTION_CODE_SIGN_IDENTITY}" \
                                           --product-sign-identity="${BUILD_TARGET_OPTION_PRODUCT_SIGN_IDENTITY}"
    common_die_on_error "Failed to build distribution package"

    build_target_invoke distribution install --debug="${debug_directory}" "${BUILD_TARGET_BUILD_DIRECTORY}"
    common_die_on_error "Failed to install distribution package"

    local distribution_package_path=""
    distribution_package_path="`osxfuse_find "${BUILD_TARGET_BUILD_DIRECTORY}"/Distribution.pkg`"
    common_die_on_error "Failed to locate distribution package"

    # Build property list signer

    build_target_xcodebuild -project prefpane/autoinstaller/autoinstaller.xcodeproj -target plist_signer \
                            VALID_ARCHS="x86_64" \
                            clean build
    common_die_on_error "Failed to build property list signer"

    # Create disk image

    common_log -v 3 "Build release disk image"

    local disk_image_path_rw="${BUILD_TARGET_BUILD_DIRECTORY}/osxfuse-${osxfuse_version}-rw.dmg"
    local disk_image_path="${BUILD_TARGET_BUILD_DIRECTORY}/osxfuse-${osxfuse_version}.dmg"

    /usr/bin/hdiutil create \
                     -layout NONE -size 16m -fs HFS+ -fsargs "-c c=64,a=16,e=16" \
                     -volname "FUSE for OS X" \
                     "${disk_image_path_rw}" 1>&3 2>&4
    common_die_on_error "Failed to create disk image"

    # Attach disk image

    local disk_image_mount_point=""

    function detach_exit_on_error
    {
        if (( ${?} != 0 ))
        then
            if [[ -n "${disk_image_mount_point}" ]]
            then
                /usr/bin/hdiutil detach "${disk_image_mount_point}" 1>&3 2>&4
            fi
            common_die "${@}"
        fi
    }

    disk_image_mount_point="`/usr/bin/hdiutil attach -private -nobrowse "${disk_image_path_rw}" 2>&4 | /usr/bin/cut -d $'\t' -f 3`"
    common_die_on_error "Failed to attach disk image '${disk_image_path_rw}'"

    # Copy license to disk image

    /bin/cp -a "${BUILD_SOURCE_DIRECTORY}/support/DiskImage/License.rtf" "${disk_image_mount_point}/License.rtf" 1>&3 2>&4
    detach_exit_on_error "Failed to copy license to disk image"

    /usr/bin/xcrun SetFile -a E "${disk_image_mount_point}/License.rtf" 1>&3 2>&4
    detach_exit_on_error "Failed to hide extension of license"

    # Copy extras to disk image

    /bin/cp -a "${BUILD_SOURCE_DIRECTORY}/support/DiskImage/Extras" "${disk_image_mount_point}/Extras" 1>&3 2>&4
    detach_exit_on_error "Failed to copy extras to disk image"

    /usr/bin/xcrun SetFile -a E "${disk_image_mount_point}/Extras"/* 1>&3 2>&4
    detach_exit_on_error "Failed to hide extension of extras"

    # Sign extras

    local application_path=""
    for application_path in "${disk_image_mount_point}/Extras"/*.app
    do
        build_target_codesign "${application_path}"
        detach_exit_on_error "Failed to sign resource '${application_path}'"
    done

    # Copy distribution package to disk image

    local disk_image_distribution_package_relative_path="Extras/FUSE for OS X ${osxfuse_version}.pkg"
    local disk_image_distribution_package_path="${disk_image_mount_point}/${disk_image_distribution_package_relative_path}"

    /bin/cp -a "${distribution_package_path}" "${disk_image_distribution_package_path}" 1>&3 2>&4
    detach_exit_on_error "Failed to copy distribution package to disk image"

    /usr/bin/xcrun SetFile -a E "${disk_image_distribution_package_path}" 1>&3 2>&4
    detach_exit_on_error "Failed to hide extension of distribution package"

    /bin/ln -s "${disk_image_distribution_package_relative_path}" "${disk_image_mount_point}/FUSE for OS X"
    detach_exit_on_error "Failed to create distribution package link"

    # Create autoinstaller engine file

    local disk_image_engine_install_path="${disk_image_mount_point}/.engine_install"

/bin/cat > "${disk_image_engine_install_path}" <<EOF
#!/bin/sh -p
/usr/sbin/installer -pkg "\$1/${disk_image_distribution_package_relative_path}" -target /
EOF

    /bin/chmod +x "${disk_image_engine_install_path}"
    detach_exit_on_error "Failed to change mode of autoinstaller engine file"

    # Copy custom background to disk image

    /bin/mkdir -p "${disk_image_mount_point}/.background" 1>&3 2>&4 && \
    /bin/cp -a "${BUILD_SOURCE_DIRECTORY}/support/DiskImage/background.tiff" "${disk_image_mount_point}/.background/background.tiff" 1>&3 2>&4
    detach_exit_on_error "Failed to copy background image to disk image"

    # Alter view options of disk image

osascript 1>&3 2>&4 <<EOF
tell application "Finder"
    tell disk "FUSE for OS X"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set the bounds of container window to {0, 0, 550, 325}
        set theViewOptions to the icon view options of container window
        set arrangement of theViewOptions to not arranged
        set icon size of theViewOptions to 96
        set text size of theViewOptions to 12
        set background picture of theViewOptions to file ".background:background.tiff"
        set position of item "License" of container window to {125, 165}
        set position of item "FUSE for OS X" of container window to {275, 165}
        set position of item "Extras" of container window to {425, 165}
        close
        open
        update without registering applications
        close
    end tell
end tell
EOF
    detach_exit_on_error "Failed to alter disk image view options"

    sync
    sleep 1

    # Detach disk image

    /usr/bin/hdiutil detach "${disk_image_mount_point}" 1>&3 2>&4
    common_die_on_error "Failed to detach disk image"

    disk_image_mount_point=""

    # Convert to read-only, compressed disk image

    /usr/bin/hdiutil convert -imagekey zlib-level=9 -format UDZO "${disk_image_path_rw}" \
                             -o "${disk_image_path}" 1>&3 2>&4 && \
    /bin/rm -f "${disk_image_path_rw}" && \
    common_die_on_error "Failed to finalize disk image"

    # Create autoinstaller rules file

    common_log -v 3 "Create autoinstaller rules file"

    local -i disk_image_size=0
    disk_image_size="`stat -f%z "${disk_image_path}"`"
    common_die_on_error "Failed to determine size of disk image"

    local disk_image_hash=""
    disk_image_hash="`openssl sha1 -binary "${disk_image_path}" | openssl base64`"
    common_die_on_error "Failed to compute hash of disk image"

    local rules_plist_path="${BUILD_TARGET_BUILD_DIRECTORY}/Release.plist"
    local download_url="http://sourceforge.net/projects/osxfuse/files/osxfuse-${osxfuse_version}/${disk_image_path##*/}/download"

/bin/cat > "${rules_plist_path}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Rules</key>
    <array>
EOF

    for osx_version in 10.5 10.6 10.7 10.8 10.9 10.10
    do
/bin/cat >> "${rules_plist_path}" <<EOF
        <dict>
            <key>ProductID</key>
            <string>com.github.osxfuse.OSXFUSE</string>
            <key>Predicate</key>
            <string>SystemVersion.ProductVersion beginswith "${osx_version}" AND Ticket.version != "${osxfuse_version}"</string>
            <key>Version</key>
            <string>${osxfuse_version}</string>
            <key>Codebase</key>
            <string>${download_url}</string>
            <key>Hash</key>
            <string>${disk_image_hash}</string>
            <key>Size</key>
            <string>${disk_image_size}</string>
        </dict>
EOF
    done

/bin/cat >> "${rules_plist_path}" <<EOF
    </array>
</dict>
</plist>
EOF

    # Sign autoinstaller rules file

    local plist_signer_path=""
    plist_signer_path="`osxfuse_find "${BUILD_TARGET_BUILD_DIRECTORY}/plist_signer"`"
    common_die_on_error "Failed to locate property list signer"

    "${plist_signer_path}" --sign --key "${RELEASE_RULES_PLIST_PRIVATE_KEY_PATH}" "${rules_plist_path}" 1>&3 2>&4
    common_die_on_error "Failed to sign autoinstaller rules file"

    # Archive debug information

    common_log -v 3 "Archive debug information"

    /usr/bin/tar -cjv \
                 -f "${BUILD_TARGET_BUILD_DIRECTORY}/osxfuse-${osxfuse_version}-debug.tbz" \
                 -C "${debug_directory}/.." \
                 "${debug_directory##*/}" 1>&3 2>&4
    common_die_on_error "Failed to archive debug information"

    # Cean up

    /bin/rm -rf "${distribution_package_path}" "${debug_directory}"
    common_warn_on_error "Failed to clean up"
}
