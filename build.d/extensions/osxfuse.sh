#!/bin/bash

# Copyright (c) 2011-2017 Benjamin Fleischer
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


declare -r OSXFUSE_PACKAGE_DIRECTORY="${BUILD_SOURCE_DIRECTORY}/support/Packages"


function osxfuse_find
{
    if [[ ! -e "${1}" ]]
    then
        return 1
    else
        printf "%s" "${1}"
    fi
}

function osxfuse_get_define
{
    local name="${1}"
    local file="${2}"

    if [[ "${file}" =~ ^/ ]]
    then
        common_assert "[[ -e `string_escape "${file}"` ]]" "File '${file}' does not exist"
    fi

    local value="$(
/bin/cat <<EOF | /usr/bin/xcrun clang -E -I"${BUILD_SOURCE_DIRECTORY}/common" -mmacosx-version-min=10.0 - | /usr/bin/tail -1
#include "${file}"
${name}
EOF
)"

    if [[ "${value}" =~ ^\".*\"$ ]]
    then
        eval "printf \"%b\" ${value}"
    else
        printf "%s" "${value}"
    fi
}

function osxfuse_get_version
{
    local version="`osxfuse_get_define OSXFUSE_VERSION "fuse_version.h"`"
    if [[ -n "${version}" ]]
    then
        printf "%s" "${version}"
    else
        return 1
    fi
}

function osxfuse_build_component_package
{
    local -a options=()
    common_getopt options "n:,name:,r:,root:" "${@}"
    common_die_on_error "${options[@]}"

    set -- "${options[@]}"

    local name=""
    local root=""

    while [[ ${#} -gt 0 ]]
    do
        case "${1}" in
            --)
                shift
                break
                ;;
            -n|--name)
                name="${2}"
                shift 2
                ;;
            -r|--root)
                root="${2}"
                shift 2
                ;;
        esac
    done

    local package_target_path="${1}"

    common_assert "[[ -d `string_escape "${root}"` ]]" "Root directory '${root}' does not exist"

    local identifier="com.github.osxfuse.pkg.${name}"
    local version=""
    local resources_directory="${OSXFUSE_PACKAGE_DIRECTORY}/${name}"

    version="`osxfuse_get_version`"
    common_die_on_error "Failed to determine osxfuse version number"

    # Create component property list

    local component_plist_path="${name}.plist"

    build_target_pkgbuild --analyze --root "${root}" "${component_plist_path}"
    common_die_on_error "Failed to create component property list"

    function osxfuse_build_package_update_component_plist
    {
        local file="${1}"
        local entry="${2}"

        plist_set "${file}" "${entry}:BundleIsVersionChecked" bool false
        plist_set "${file}" "${entry}:BundleOverwriteAction" string upgrade
    }

    build_target_pkgbuild_component_plist_foreach "${component_plist_path}" "" osxfuse_build_package_update_component_plist
    common_die_on_error "Failed to update component property list"

    unset osxfuse_build_package_update_component_plist

    # Build package

    local -a command=(build_target_pkgbuild --identifier "${identifier}" \
                                            --version "${version}" \
                                            --ownership recommended \
                                            --root "${root}" \
                                            --component-plist "${component_plist_path}")

    if [[ -n "${resources_directory}" && -d "${resources_directory}/Scripts" ]]
    then
        command+=(--scripts "${resources_directory}/Scripts")
    fi

    command+=("${package_target_path}")

    "${command[@]}"
}

function osxfuse_build_distribution_package
{
    local -a options=()
    common_getopt options "package-path:,c:,component-package:,plugin-path:,d:,deployment-target:" "${@}"
    common_die_on_error "${options[@]}"

    set -- "${options[@]}"

    local    plugin_path=""
    local    package_path=""
    local -a component_packages=()
    local -a deployment_targets=()

    while [[ ${#} -gt 0 ]]
    do
        case "${1}" in
            --)
                shift
                break
                ;;
            -p|--package-path)
                package_path="${2}"
                shift 2
                ;;
            -c|--component-package)
                component_packages+=("${2}")
                shift 2
                ;;
            --plugin-path)
                plugin_path="${2}"
                shift 2
                ;;
            -d|--deployment-target)
                deployment_targets+=("${2}")
                shift 2
                ;;

        esac
    done

    local package_target_path="${1}"

    common_assert "[[ ${#component_packages[@]} -gt 0 ]]" "At least one component package is required"

    local -a component_packages_identifiers=()
    for path in "${component_packages[@]}"
    do
        /usr/bin/xar -x -f "${path}" PackageInfo && \
        component_packages_identifiers+=("`/usr/bin/xpath PackageInfo 'string(/pkg-info/@identifier)' 2> /dev/null`") && \
        rm -f PackageInfo
        common_die_on_error "Failed to determine component package identifier of package '${path}'"
    done

    local installation_check_condition="false"
    for deployment_target in "${deployment_targets[@]}"
    do
        installation_check_condition="${installation_check_condition} || isProductVersion('${deployment_target}')"
    done

/bin/cat > Distribution <<EOF
<?xml version="1.0" encoding="utf-8" standalone="no"?>
<installer-gui-script minSpecVersion="1">
    <title>FUSE for macOS</title>
    <welcome file="Welcome.rtf"/>
    <license file="License.rtf"/>
    <options customize="always" rootVolumeOnly="true" require-scripts="false"/>
EOF

    local i=0
    for (( ; i < ${#component_packages[@]} ; i++ ))
    do
        local identifier="${component_packages_identifiers[${i}]}"
        local basename="`basename "${component_packages[${i}]}"`"
        local name="`string_uppercase <<< "${identifier##*.}"`"

/bin/cat >> Distribution <<EOF
    <choice id="${identifier}"
            title="${name}_TITLE"
            description="${name}_DESCRIPTION"
            start_selected="isChoiceSelected('${identifier}')"
            start_enabled="isChoiceEnabled('${identifier}')"
            visible="isChoiceVisible('${identifier}')">
        <pkg-ref id="${identifier}"/>
    </choice>
    <pkg-ref id="${identifier}" auth="root" onConclusion="none">${basename}</pkg-ref>
EOF
    done

/bin/cat >> Distribution <<EOF
    <choices-outline>
EOF

    for identifier in "${component_packages_identifiers[@]}"
    do
/bin/cat >> Distribution <<EOF
        <line choice="${identifier}"/>
EOF
    done

/bin/cat >> Distribution <<EOF
    </choices-outline>
    <installation-check script='installationCheck()'/>
    <script><![CDATA[
        function isProductVersion(version) {
            return system.version.ProductVersion.slice(0, version.length) == version;
        }

        function getChoice(package) {
            return choices[package];
        }

        function installationCheck() {
            if (${installation_check_condition}) return true;

            my.result.type = 'Fatal';
            my.result.message = system.localizedString('ERROR_OSXVERSION');
            return false;
        }

        function choiceConflictCheck(package) {
            switch (package) {
                default: return false;
            }
        }

        function isPackageInstalled() {
            return getChoice('com.github.osxfuse.pkg.Core').packageUpgradeAction != 'clean';
        }

        function isChoiceDefaultSelected(package) {
            switch (package) {
                case 'com.github.osxfuse.pkg.Core': return true;
                case 'com.github.osxfuse.pkg.PrefPane': return true;
                default: return false;
            }
        }

        function isChoiceDefaultEnabled(package) {
            switch (package) {
                case 'com.github.osxfuse.pkg.Core': return false;
                default: return true;
            }
        }

        function isChoiceInstalled(package) {
            if (getChoice(package).packageUpgradeAction != 'clean') {
                return true;
            }

            switch (package) {
                default: return false;
            }
        }

        function isChoiceRequired(package) {
            return isChoiceInstalled(package) && !choiceConflictCheck(package);
        }

        function isChoiceSelected(package) {
            return (!isPackageInstalled() && isChoiceDefaultSelected(package)) || isChoiceRequired(package);
        }

        function isChoiceEnabled(package) {
            return isChoiceDefaultEnabled(package) && !isChoiceRequired(package);
        }

        function isChoiceVisible(package) {
            return true;
        }
    ]]></script>
</installer-gui-script>
EOF

    build_target_productbuild --distribution Distribution \
                              --package-path "${package_path}" \
                              --resources "${OSXFUSE_PACKAGE_DIRECTORY}/Distribution/Resources" \
                              --plugins "${plugin_path}" \
                              "${package_target_path}"
}
