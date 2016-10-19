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


declare -ra BUILD_TARGET_ACTIONS=("build" "clean")

declare     BUILD_TARGET_OPTION_CODE_SIGN_IDENTITY="Developer ID Application: Benjamin Fleischer"
declare     BUILD_TARGET_OPTION_PRODUCT_SIGN_IDENTITY="Developer ID Installer: Benjamin Fleischer"

declare -r  RELEASE_RULES_PLIST_PRIVATE_KEY_PATH="${HOME}/.osxfuse_private_key"
declare -i  RELEASE_CREATE_DSSTORE=0


function release_build
{
    function release_build_getopt_handler
    {
        case "${1}" in
            --auto-create-dsstore)
                RELEASE_CREATE_DSSTORE=0
                return 1
                ;;
            --create-dsstore)
                RELEASE_CREATE_DSSTORE=1
                return 1
                ;;
        esac
    }

    build_target_getopt -p meta -s "auto-create-dsstore,create-dsstore" -h release_build_getopt_handler -- "${@}"
    unset release_build_getopt_handler

    common_log_variable RELEASE_CREATE_DSSTORE

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

    build_target_invoke distribution build -s 10.9 -d 10.9 -c Release \
                                           --kext=10.9 --kext="10.10->10.9" --kext="10.11->10.9" --kext="10.12->10.9" \
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
                            ONLY_ACTIVE_ARCH="YES" \
                            clean build
    common_die_on_error "Failed to build property list signer"

    # Create disk image

    common_log -v 3 "Build release disk image"

    local disk_image_resources_path="${BUILD_SOURCE_DIRECTORY}/support/DiskImage"

    local disk_image_path_stage="${BUILD_TARGET_BUILD_DIRECTORY}/stage.dmg"
    local disk_image_path="${BUILD_TARGET_BUILD_DIRECTORY}/osxfuse-${osxfuse_version}.dmg"

    /usr/bin/hdiutil create -size 16m -fs HFS+ -volname "FUSE for macOS" -fsargs "-c c=64,a=16,e=16" -layout NONE \
                            "${disk_image_path_stage}" 1>&3 2>&4
    common_die_on_error "Failed to create disk image"

    # Attach disk image

    local disk_image_mount_point=""

    function detach_die_on_error
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

    disk_image_mount_point="`/usr/bin/hdiutil attach -private -nobrowse "${disk_image_path_stage}" 2>&4 | /usr/bin/cut -d $'\t' -f 3`"
    common_die_on_error "Failed to attach disk image '${disk_image_path_stage}'"

    # Remove .Trashes directory from disk image

    /bin/chmod 755 "${disk_image_mount_point}/.Trashes" 1>&3 2>&4 && \
    /bin/rm -rf "${disk_image_mount_point}/.Trashes" 1>&3 2>&4
    common_die_on_error "Failed to remove .Trashes directory from disk image"

    # Copy license to disk image

    /bin/cp -pPR "${disk_image_resources_path}/License.rtf" "${disk_image_mount_point}/License.rtf" 1>&3 2>&4
    detach_die_on_error "Failed to copy license to disk image"

    /usr/bin/xcrun SetFile -a E "${disk_image_mount_point}/License.rtf" 1>&3 2>&4
    detach_die_on_error "Failed to hide extension of license"

    # Copy extras to disk image

    /bin/cp -pPR "${disk_image_resources_path}/Extras" "${disk_image_mount_point}/Extras" 1>&3 2>&4
    detach_die_on_error "Failed to copy extras to disk image"

    /usr/bin/xcrun SetFile -a E "${disk_image_mount_point}/Extras"/* 1>&3 2>&4
    detach_die_on_error "Failed to hide extension of extras"

    # Sign extras

    local application_path=""
    for application_path in "${disk_image_mount_point}/Extras"/*.app
    do
        build_target_codesign "${application_path}"
        detach_die_on_error "Failed to sign resource '${application_path}'"
    done

    # Copy distribution package to disk image

    local disk_image_distribution_package_relative_path="Extras/FUSE for macOS ${osxfuse_version}.pkg"
    local disk_image_distribution_package_path="${disk_image_mount_point}/${disk_image_distribution_package_relative_path}"

    /bin/cp -pPR "${distribution_package_path}" "${disk_image_distribution_package_path}" 1>&3 2>&4
    detach_die_on_error "Failed to copy distribution package to disk image"

    /usr/bin/xcrun SetFile -a E "${disk_image_distribution_package_path}" 1>&3 2>&4
    detach_die_on_error "Failed to hide extension of distribution package"

    /bin/ln -s "${disk_image_distribution_package_relative_path}" "${disk_image_mount_point}/FUSE for macOS.pkg"
    detach_die_on_error "Failed to create distribution package symlink"

    /usr/bin/xcrun SetFile -P -a E "${disk_image_mount_point}/FUSE for macOS.pkg" 1>&3 2>&4
    detach_die_on_error "Failed to hide extension of distribution package symlink"

    # Create autoinstaller engine file

    local disk_image_engine_install_path="${disk_image_mount_point}/.engine_install"

/bin/cat > "${disk_image_engine_install_path}" <<EOF
#!/bin/sh -p
/usr/sbin/installer -pkg "\$1/${disk_image_distribution_package_relative_path}" -target /
EOF

    /bin/chmod +x "${disk_image_engine_install_path}"
    detach_die_on_error "Failed to change mode of autoinstaller engine file"

    # Copy custom background to disk image

    /bin/mkdir -p "${disk_image_mount_point}/.Background" 1>&3 2>&4 && \
    /bin/cp -pPR "${disk_image_resources_path}/Background.tiff" "${disk_image_mount_point}/.Background/Background.tiff" 1>&3 2>&4
    detach_die_on_error "Failed to copy background image to disk image"

    # Customize view options of disk image

    local disk_image_view_options='
            set current view of container window to icon view
            set toolbar visible of container window to false
            set the bounds of container window to {0, 0, 550, 372}

            set theViewOptions to the icon view options of container window
            set arrangement of theViewOptions to not arranged
            set icon size of theViewOptions to 96
            set text size of theViewOptions to 12
            set background picture of theViewOptions to file ".Background:Background.tiff"

            set position of item "License.rtf" of container window to {125, 170}
            set position of item "FUSE for macOS.pkg" of container window to {275, 170}
            set position of item "Extras" of container window to {425, 170}'

    local disk_image_view_options_digest=""
    disk_image_view_options_digest="`/usr/bin/openssl dgst -sha256 <<< "${disk_image_view_options}"`"
    detach_die_on_error "Failed to compute digest of view options"

    if (( RELEASE_CREATE_DSSTORE == 0 ))
    then
        local disk_image_dsstore_tag=""
        disk_image_dsstore_tag="$(/usr/bin/sed -n '1p' "${disk_image_resources_path}/DS_Store" 2> /dev/null)"

        if [[ "${disk_image_view_options_digest}" != "${disk_image_dsstore_tag}" ]]
        then
            RELEASE_CREATE_DSSTORE=1
        fi
    fi

    if (( RELEASE_CREATE_DSSTORE  != 0 ))
    then
        common_log -v 3 "Customize disk image view options"

osascript 1>&3 2>&4 <<EOF
tell application "Finder"
    tell disk "FUSE for macOS"
        open
        delay 1
        ${disk_image_view_options}
        delay 1
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF
        detach_die_on_error "Failed to customize disk image view options"

        sync
        sleep 1

        printf "%s\n" "${disk_image_view_options_digest}" > "${disk_image_resources_path}/DS_Store" 2>&4
        detach_die_on_error "Failed to update cache tag of disk image .DS_Store file"

        /bin/cat "${disk_image_mount_point}/.DS_Store" >> "${disk_image_resources_path}/DS_Store" 2>&4
        detach_die_on_error "Failed to update cached disk image .DS_Store file"
    else
        /usr/bin/sed -n '1,1!p' "${disk_image_resources_path}/DS_Store" > "${disk_image_mount_point}/.DS_Store" 2>&4
        detach_die_on_error "Failed to copy cached .DS_Store file to disk image"
    fi

    # Detach disk image

    /usr/bin/hdiutil detach "${disk_image_mount_point}" 1>&3 2>&4
    common_die_on_error "Failed to detach disk image"

    disk_image_mount_point=""

    # Convert to read-only, compressed disk image

    /usr/bin/hdiutil convert -imagekey zlib-level=9 -format UDZO "${disk_image_path_stage}" \
                             -o "${disk_image_path}" 1>&3 2>&4 && \
    /bin/rm -f "${disk_image_path_stage}"
    common_die_on_error "Failed to finalize disk image"

    # Create autoinstaller rules file

    common_log -v 3 "Create autoinstaller rules file"

    local -i disk_image_size=0
    disk_image_size="`stat -f%z "${disk_image_path}"`"
    common_die_on_error "Failed to determine size of disk image"

    local disk_image_digest=""
    disk_image_digest="`/usr/bin/openssl dgst -sha1 -binary "${disk_image_path}" | /usr/bin/openssl enc -base64`"
    common_die_on_error "Failed to compute hash of disk image"

    local rules_plist_path="${BUILD_TARGET_BUILD_DIRECTORY}/Release.plist"
    local download_url="https://github.com/osxfuse/osxfuse/releases/download/osxfuse-${osxfuse_version}/`basename "${disk_image_path}"`"

/bin/cat > "${rules_plist_path}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Rules</key>
    <array>
EOF

    for osx_version in 10.9 10.10 10.11 10.12
    do
/bin/cat >> "${rules_plist_path}" <<EOF
        <dict>
            <key>ProductID</key>
            <string>com.github.osxfuse.OSXFUSE</string>
            <key>Predicate</key>
            <string>SystemVersion.ProductVersion beginswith "${macos_version}" AND Ticket.version != "${osxfuse_version}"</string>
            <key>Version</key>
            <string>${osxfuse_version}</string>
            <key>Codebase</key>
            <string>${download_url}</string>
            <key>Hash</key>
            <string>${disk_image_digest}</string>
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
                 "`basename "${debug_directory}"`" 1>&3 2>&4
    common_die_on_error "Failed to archive debug information"

    # Cean up

    /bin/rm -rf "${distribution_package_path}" "${debug_directory}"
    common_warn_on_error "Failed to clean up"
}
