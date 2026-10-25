#!/bin/sh
set -eu

package_name=belkin-bbz002
package_version=0.1
source_dir="/usr/src/$package_name-$package_version"

if [ "$(id -u)" -ne 0 ]; then
	echo "Run this uninstaller with sudo." >&2
	exit 1
fi

if [ ! -e "/var/lib/dkms/$package_name/$package_version" ]; then
	echo "No DKMS installation found for $package_name $package_version." >&2
	exit 1
fi

dkms remove -m "$package_name" -v "$package_version" --all

if [ -d "$source_dir" ]; then
	for file in Makefile dkms.conf hid-apple.c hid-ids.h; do
		rm -- "$source_dir/$file"
	done
	rmdir "$source_dir"
fi

echo "DKMS module removed. Reboot to load the distribution driver."
