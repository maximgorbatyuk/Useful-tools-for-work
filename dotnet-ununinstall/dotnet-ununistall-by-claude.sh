#!/usr/bin/env bash
#
# Copyright (c) .NET Foundation and contributors. All rights reserved.
# Licensed under the MIT license. See LICENSE file in the project root for full license information.
#

set -e

current_userid=$(id -u)
if [ "$current_userid" -ne 0 ]; then
    echo "$(basename "$0") uninstallation script requires superuser privileges to run" >&2
    exit 1
fi

dotnet_pkg_name_suffix="com.microsoft.dotnet"
dotnet_install_root="/usr/local/share/dotnet"
dotnet_path_file="/etc/paths.d/dotnet"

remove_dotnet_pkgs(){
    local exit_code=0
    local installed_pkgs=()
    mapfile -t installed_pkgs < <(pkgutil --pkgs | grep "$dotnet_pkg_name_suffix" || true)
    
    if [ ${#installed_pkgs[@]} -eq 0 ]; then
        echo "No .NET packages found in pkgutil database." >&2
        return 0
    fi
    
    for i in "${installed_pkgs[@]}"
    do
        echo "Removing dotnet component - \"$i\"" >&2
        if ! pkgutil --force --forget "$i"; then
            echo "Warning: Failed to forget package $i" >&2
            exit_code=1
        fi
    done
    return $exit_code
}

# Confirmation prompt
read -p "This will completely remove all .NET installations. Continue? (y/N): " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
    echo "Aborted." >&2
    exit 0
fi

remove_dotnet_pkgs
pkg_result=$?

if [ -d "$dotnet_install_root" ]; then
    echo "Deleting install root - $dotnet_install_root" >&2
    rm -rf "$dotnet_install_root"
else
    echo "Install root not found - $dotnet_install_root" >&2
fi

if [ -f "$dotnet_path_file" ]; then
    echo "Removing PATH file - $dotnet_path_file" >&2
    rm -f "$dotnet_path_file"
fi

if [ $pkg_result -ne 0 ]; then
    echo "Completed with warnings - some packages may not have been removed." >&2
    exit 1
fi

echo "dotnet packages removal succeeded." >&2
exit 0