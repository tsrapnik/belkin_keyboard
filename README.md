# Belkin BBZ002 Linux driver

This repository contains an experimental out-of-tree Linux HID driver for the
Belkin BBZ002 keyboard and touchpad. The device identifies over Bluetooth as
`05ac:0239` and is handled by a customized `hid-apple` driver.

The custom module replaces the kernel's `hid_apple` module; it is not an
independent add-on. The touchpad gesture handling is still being improved.
The driver has been build-tested on Pop!_OS 24.04 with kernel 6.17.

## Build

Install the build tools and headers for the running kernel:

```sh
sudo apt install build-essential linux-headers-$(uname -r)
make
```

This builds `hid-apple.ko` in the repository and does not install or load it.
To build for another installed kernel, set `KDIR`:

```sh
make KDIR=/lib/modules/<kernel-version>/build
```

Clean generated build files with `make clean`.

## Tune pointer speed

BBZ002 pointer movement defaults to 90% of the device-reported delta. Fractional
movement is carried between reports so small movements are not discarded. The
`pointer_speed` module parameter accepts values from 10 to 100:

```sh
echo 70 | sudo tee /sys/module/hid_apple/parameters/pointer_speed
```

The change applies immediately and can be adjusted between 10 (slowest) and
100 (unscaled).

## Install with DKMS

DKMS builds the module for the running kernel and rebuilds it when a new
kernel is installed. This installs a module overlay; it does not delete or
overwrite the distribution's copy. Review the driver changes and keep a
recovery input device available before installing.

If you previously followed the old manual instructions that copied this
module into `/lib/modules`, restore the distribution-owned copy first:

```sh
sudo apt install --reinstall linux-modules-$(uname -r)
```

If the old hand-copied `hid-apple.ko` remains alongside the restored module,
verify it is not package-owned with `dpkg-query -S <path>`. Only if it is
unowned, remove that hand-copied file and refresh the module index:

```sh
sudo rm /lib/modules/$(uname -r)/kernel/drivers/hid/hid-apple.ko
sudo depmod -a
```

The installer checks for this situation and refuses to continue if it finds an
unpackaged module in the kernel's module directory.

```sh
sudo apt install dkms
sudo ./scripts/install-dkms.sh
sudo reboot
```

The reboot loads the DKMS module. To remove the overlay and return to the
distribution driver:

```sh
sudo ./scripts/uninstall-dkms.sh
sudo reboot
```

The install scripts use the fixed DKMS version in `dkms.conf`. When preparing
a new release, increment the version there and in both scripts.

## Test the module

Replacing `hid_apple` temporarily disconnects the keyboard while the module is
reloaded. Use a separate keyboard or ensure you have another way to recover.
Do not remove or overwrite files in `/lib/modules` by hand.

After building, the module can be tested for the current boot with:

```sh
sudo modprobe -r hid_apple
sudo insmod ./hid-apple.ko
```

To reload the module selected by the system before rebooting:

```sh
sudo modprobe -r hid_apple
sudo modprobe hid_apple
```

The reload command selects whichever module is installed for the current
kernel. If the DKMS overlay is installed, run the uninstaller and reboot to
restore the distribution module. A reboot alone does not restore a module
previously copied manually into `/lib/modules`.

## Verify input events

Find the BBZ002 event node by name; event numbers can change after reconnects:

```sh
grep -B 4 -A 2 'BELKIN BBZ002' /proc/bus/input/devices
```

Then inspect its events (replace `eventN` with the node listed on the
`Handlers` line):

```sh
sudo evtest /dev/input/eventN
```

Check keyboard keys, pointer motion, and physical click. A one-finger tap
clicks; double-tap and hold to drag. Also test two-finger scroll and two-finger
tap for right-click. While checking pointer movement, confirm that moving one
finger without tapping does not click. Stop `evtest` with Ctrl-C.

## Known limitations

- The module is based on the kernel `hid-apple` driver and must be rebuilt for
  each kernel version.
- Gesture support and smoothness are under active development; no claim of
  complete macOS feature parity is made.
- Persistent installation should use a reversible, kernel-upgrade-aware
  mechanism such as DKMS. Do not replace the distro's module manually.

## License

The driver sources are licensed under GPL-2.0-or-later, as indicated in their
SPDX headers.
