#!/bin/sh
set -eu

package_name=belkin-bbz002
package_version=0.1
source_dir="/usr/src/$package_name-$package_version"
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

if [ "$(id -u)" -ne 0 ]; then
	echo "Run this installer with sudo." >&2
	exit 1
fi

if ! command -v dkms >/dev/null 2>&1; then
	echo "DKMS is not installed. Install it with: sudo apt install dkms" >&2
	exit 1
fi

module_dir="/lib/modules/$(uname -r)/kernel/drivers/hid"
set -- "$module_dir"/hid-apple.ko*
owned_stock_module=false
for module_file do
	[ -e "$module_file" ] || continue
	# On usrmerged systems dpkg records the /usr/lib path, not /lib.
	if ! dpkg-query -S "$module_file" >/dev/null 2>&1 &&
		! dpkg-query -S "$(readlink -f -- "$module_file")" >/dev/null 2>&1; then
		echo "Unpackaged hid-apple module found: $module_file" >&2
		echo "Restore the distro package with:" >&2
		echo "  sudo apt install --reinstall linux-modules-$(uname -r)" >&2
		echo "Then remove the unpackaged file above and run sudo depmod -a." >&2
		exit 1
	fi
	owned_stock_module=true
done

if [ "$owned_stock_module" != true ]; then
	echo "No distro-owned hid-apple module found under $module_dir." >&2
	echo "Restore the kernel module package before installing this driver." >&2
	exit 1
fi

if [ -e "$source_dir" ] || [ -e "/var/lib/dkms/$package_name/$package_version" ]; then
	echo "DKMS source or registration already exists for $package_name $package_version." >&2
	echo "Remove that version or increment the version before installing." >&2
	exit 1
fi

install -d "$source_dir"
install -m 0644 "$repo_dir/Makefile" "$repo_dir/dkms.conf" \
	"$repo_dir/hid-apple.c" "$repo_dir/hid-ids.h" "$source_dir/"

dkms add -m "$package_name" -v "$package_version"
dkms build -m "$package_name" -v "$package_version"
dkms install -m "$package_name" -v "$package_version"

echo "DKMS installation complete. Reboot to load the installed module."
