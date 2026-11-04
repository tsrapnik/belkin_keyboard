# Belkin BBZ002 Linux driver

## Quick start

1. Pair the keyboard in the Bluetooth settings.
2. Run the installer and reboot:

   ```sh
   sudo ./install.sh
   sudo reboot
   ```

That's it. To undo everything: `sudo ./uninstall.sh && sudo reboot`.

The installer is for Debian-based systems such as Pop!_OS and Ubuntu. It
installs the build dependencies, the driver (with DKMS, so it is rebuilt for
new kernels) and the Bluetooth connection interval fix, and marks the keyboard
as trusted so it reconnects by itself. Run it again after updating the
repository. The sections below explain each part.

This repository contains an experimental out-of-tree Linux HID driver for the
Belkin BBZ002 keyboard and touchpad. The device identifies over Bluetooth as
`05ac:0239` and is handled by a customized `hid-apple` driver.

The custom module replaces the kernel's `hid_apple` module; it is not an
independent add-on. The driver has been build-tested on Pop!_OS 24.04 with
kernel 6.17.

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

## Touchpad

The touchpad is registered as a separate multitouch input device named
`BELKIN BBZ002 Touchpad`. libinput treats it like any other touchpad, so
tapping, tap-and-drag, scrolling, gestures and pointer speed are configured in
the desktop's touchpad settings.

If a lift report is lost, the driver treats a contact that reappears far away
after a report gap as a new touch. The gap defaults to 100 ms and can be
adjusted between 10 and 1000 ms:

```sh
echo 150 | sudo tee /sys/module/hid_apple/parameters/touch_gap_ms
```

### Faster Bluetooth connection interval

Bluetooth LE delivers touchpad reports in bursts once per connection interval.
The BBZ002 asks for 15 to 30 ms and Linux ends up at 30 ms, so the pointer
moves in visible steps. A udev rule can pin the interval to 7.5 ms a few
seconds after the keyboard connects. It uses `hcitool` from the `bluez`
package:

```sh
sudo install -D -m 0755 scripts/bbz002-ble-interval /usr/local/libexec/bbz002-ble-interval
sudo install -m 0644 udev/99-bbz002-ble-interval.rules /etc/udev/rules.d/
sudo udevadm control --reload
```

It applies from the next connection. To remove it:

```sh
sudo rm /etc/udev/rules.d/99-bbz002-ble-interval.rules /usr/local/libexec/bbz002-ble-interval
sudo udevadm control --reload
```

### If the touchpad lags or disconnects

These fixes depend on the PC's Bluetooth adapter rather than the keyboard, so
the installer leaves them out. Try them only if needed.

To see what the link is doing, record a trace while moving on the touchpad and
stop it with Ctrl-C. Touchpad reports are the notifications on handle
`0x0019`; their first two bytes are the device's scan time in 100 us steps.

```sh
sudo btmon -w bbz002.snoop
btmon -r bbz002.snoop
```

#### Disable USB autosuspend

A USB Bluetooth adapter that is suspended between reports adds delay and can
drop the connection. Disable autosuspend for the current boot:

```sh
echo -1 | sudo tee /sys/module/usbcore/parameters/autosuspend
for f in /sys/bus/usb/devices/*/power/control; do echo on | sudo tee "$f" >/dev/null; done
```

To keep it disabled, add `usbcore.autosuspend=-1` to the kernel command line.
On Pop!_OS:

```sh
sudo kernelstub -a "usbcore.autosuspend=-1"
```

On systems with GRUB, add it to `GRUB_CMDLINE_LINUX_DEFAULT` in
`/etc/default/grub` and run `sudo update-grub`. Undo it on Pop!_OS with
`sudo kernelstub -d "usbcore.autosuspend=-1"`. Power managers such as TLP can
turn autosuspend back on; with TLP, set `USB_AUTOSUSPEND=0` in
`/etc/tlp.conf`.

#### Older firmware for Realtek RTL8761B adapters

Adapters with a Realtek RTL8761B chip, such as the TP-Link UB500, are reported
to drop connections with "LMP Response Timeout" on the firmware shipped in
`linux-firmware` ([Arch forum thread](https://bbs.archlinux.org/viewtopic.php?id=302528)).
Check which chip and firmware the adapter loads:

```sh
journalctl -k -b | grep -E 'RTL: (loading|fw version)'
```

If it loads `rtl_bt/rtl8761bu_fw.bin` or `rtl_bt/rtl8761b_fw.bin`, the older
firmware from the AUR package `rtl8761b-firmware` can be installed to
`/lib/firmware/updates`. The kernel prefers that directory, and package
updates do not overwrite it.

```sh
dir=$(mktemp -d)
for f in rtl8761b_config.bin rtl8761b_fw.bin rtl8761bu_config.bin rtl8761bu_fw.bin; do
	curl -sfL -o "$dir/$f" "https://aur.archlinux.org/cgit/aur.git/plain/$f?h=rtl8761b-firmware"
done
(cd "$dir" && md5sum -c <<'EOF'
783db7913e59ab81adb335684d5f83fb  rtl8761b_config.bin
973aa8ee84131d91a0475d8ce7fc680c  rtl8761b_fw.bin
49951f548b87ea0258d128195ef6e0cf  rtl8761bu_config.bin
6c3929e6a1d35f4206a8e9f763faf17e  rtl8761bu_fw.bin
EOF
) && sudo install -D -m 0644 -t /lib/firmware/updates/rtl_bt "$dir"/*.bin
sudo modprobe -r btusb && sudo modprobe btusb
```

The firmware version in the kernel log then changes, for example from
`0xdfc6d922` to `0x09a98a6b`. To return to the distribution firmware:

```sh
sudo rm -r /lib/firmware/updates/rtl_bt
sudo modprobe -r btusb && sudo modprobe btusb
```

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
