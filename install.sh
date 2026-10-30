#!/bin/sh
# Set up the Belkin BBZ002 on this PC: build dependencies, the DKMS driver,
# the Bluetooth connection interval fix, and trusting the paired keyboard.
# Safe to run again, e.g. after pulling driver changes.
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
package_name=belkin-bbz002
package_version=0.1

if [ "$(id -u)" -ne 0 ]; then
	echo "Run this installer with sudo: sudo ./install.sh" >&2
	exit 1
fi

echo "==> Installing build tools, kernel headers, DKMS and BlueZ"
apt-get install -y build-essential dkms bluez "linux-headers-$(uname -r)"

echo "==> Installing the driver with DKMS"
if [ -e "/var/lib/dkms/$package_name/$package_version" ]; then
	sh "$repo_dir/scripts/uninstall-dkms.sh"
fi
sh "$repo_dir/scripts/install-dkms.sh"

echo "==> Installing the Bluetooth connection interval rule"
install -D -m 0755 "$repo_dir/scripts/bbz002-ble-interval" \
	/usr/local/libexec/bbz002-ble-interval
install -m 0644 "$repo_dir/udev/99-bbz002-ble-interval.rules" \
	/etc/udev/rules.d/
udevadm control --reload

echo "==> Trusting the paired keyboard so it reconnects by itself"
addresses=$(bluetoothctl devices Paired | awk '/BELKIN BBZ002$/ { print $2 }')
if [ -n "$addresses" ]; then
	for address in $addresses; do
		bluetoothctl trust "$address"
	done
else
	echo "No paired BELKIN BBZ002 found. Pair it in the Bluetooth settings;"
	echo "everything else is already in place."
fi

echo
echo "Done. Reboot to load the driver: sudo reboot"
