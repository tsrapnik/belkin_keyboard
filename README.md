# Correctly recognize as keyboard.

Create:

sudo nano /etc/udev/rules.d/99-belkin-bbz002.rules


Add:

SUBSYSTEM=="input", ATTRS{name}=="BELKIN BBZ002", \
  ENV{ID_INPUT_TOUCHSCREEN}="0", \
  ENV{ID_INPUT_TABLET}="0", \
  ENV{ID_INPUT_TABLET_PAD}="0", \
  ENV{ID_INPUT_KEYBOARD}="1", \
  ENV{ID_INPUT_KEY}="1"


Then reload:

sudo udevadm control --reload
sudo udevadm trigger


Unplug / reconnect the device (or reboot).

# Update driver.

Make sure the first line in [Makefile](./Makefile) is `obj-m := hid-magicmouse.o`.

```
sudo apt update
sudo apt install linux-headers-$(uname -r)
make
sudo rmmod hid-magicmouse
sudo insmod ./hid-magicmouse.ko
```

# Verify which drivers are used.

```
ls -l /sys/bus/hid/devices/*/driver
```

# Unbind and rebind driver.

```
ls -l /sys/bus/hid/devices/0005:05AC:0239.*/driver

echo -n "0005:05AC:0239.000B" | sudo tee /sys/bus/hid/drivers/apple/unbind

ls -l /sys/bus/hid/devices/0005:05AC:0239.*/driver

echo -n "0005:05AC:0239.000B" | sudo tee /sys/bus/hid/drivers/magicmouse/bind

ls -l /sys/bus/hid/devices/0005:05AC:0239.*/driver
```

# Verify which events hid-apple supports.

sudo evtest /dev/input/event21

# Permanently install driver.

```
sudo rm /lib/modules/$(uname -r)/kernel/drivers/hid/hid-apple.ko.zst
sudo cp hid-apple.ko /lib/modules/$(uname -r)/kernel/drivers/hid/
sudo depmod
```
