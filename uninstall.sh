#!/bin/sh
# Undo install.sh: remove the DKMS driver and the Bluetooth interval rule.
# Build tools, BlueZ and the keyboard pairing are left alone.
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
package_name=belkin-bbz002
package_version=0.1

if [ "$(id -u)" -ne 0 ]; then
	echo "Run this uninstaller with sudo: sudo ./uninstall.sh" >&2
	exit 1
fi

rm -f /etc/udev/rules.d/99-bbz002-ble-interval.rules \
	/usr/local/libexec/bbz002-ble-interval
udevadm control --reload

if [ -e "/var/lib/dkms/$package_name/$package_version" ]; then
	sh "$repo_dir/scripts/uninstall-dkms.sh"
fi

echo
echo "Done. Reboot to go back to the distribution driver: sudo reboot"
